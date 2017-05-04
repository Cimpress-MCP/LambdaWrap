require 'aws-sdk'
require 'set'
require 'pathname'

module LambdaWrap
  ##
  # Lambda Manager class.
  class Lambda
    def initialize(options)
      defaults = {
        description: 'Deployed with LambdaWrap', subnet_ids: [], security_group_ids: [], timeout: 30, memory_size: 128,
        delete_unreferenced_versions: true
      }
      options_with_defaults = options.reverse_merge(defaults)

      unless (options_with_defaults[:function_name]) && (options_with_defaults[:function_name].is_a? String)
        raise ArgumentException, 'function_name must be provided (String)!'
      end
      @function_name = options_with_defaults[:function_name]

      unless (options_with_defaults[:handler]) && (options_with_defaults[:handler].is_a? String)
        raise ArgumentException, 'handler must be provided (String)!'
      end
      @handler = options_with_defaults[:handler]

      unless (options_with_defaults[:role_arn]) && (options_with_defaults[:role_arn].is_a? String)
        raise ArgumentException, 'role_arn must be provided (String)!'
      end
      @role_arn = options_with_defaults[:role_arn]

      unless (options_with_defaults[:path_to_zip_file]) && (options_with_defaults[:path_to_zip_file].is_a? String)
        raise ArgumentException, 'path_to_zip_file must be provided (String)!'
      end
      @path_to_zip_file = Pathname.new(options_with_defaults[:path_to_zip_file])

      unless (options_with_defaults[:runtime]) && (options_with_defaults[:runtime].is_a? String)
        raise ArgumentException, 'runtime must be provided (String)!'
      end

      case options_with_defaults[:runtime]
      when 'nodejs' then raise ArgumentException, 'AWS Lambda Runtime NodeJS v0.10.42 is deprecated as of April 2017. \
        Please see: https://forums.aws.amazon.com/ann.jspa?annID=4142'
      when 'nodejs4.3', 'nodejs6.10', 'java8', 'python2.7', 'python3.6', 'dotnetcore1.0', 'nodejs4.3-edge'
        @runtime = options_with_defaults[:runtime]
      else
        raise ArgumentException, "Invalid Runtime specified: #{options_with_defaults[:runtime]}. Only accepts: \
        nodejs4.3, nodejs6.10, java8, python2.7, python3.6, dotnetcore1.0, or nodejs4.3-edge"
      end

      @description = options_with_defaults[:description]

      @timeout = options_with_defaults[:timeout]

      @memory_size = options_with_defaults[:memory_size]

      @subnet_ids = options_with_defaults[:subnet_ids]
      @security_group_ids = options_with_defaults[:security_group_ids]

      if @subnet_ids.empty? ^ @security_group_ids.empty?
        raise ArgumentException, 'Must supply values for BOTH Subnet Ids and Security Group ID if VPC is desired.'
      end

      @delete_unreferenced_versions = options_with_defaults[:delete_unreferenced_versions]
    end

    def deploy(environment_options)
      super

      puts "Deploying Lambda: #{@function_name} to Environment: #{environment_options.name}"

      deployment_package_blob = load_deployment_package_blob

      lambda_details = retrieve_lambda_details

      if lambda_details.nil?
        function_version = create_lambda(deployment_package_blob)
      else
        update_lambda_config
        function_version = update_lambda_code(deployment_package_blob)
      end

      create_alias(@function_name, function_version, environment_options[:name])

      cleanup_unused_versions(@function_name) if delete_unreferenced_versions

      puts "Lambda: #{@function_name} successfully deployed!"
    end

    def teardown(environment_options)
      super
      remove_alias(@function_name, environment_options[:name])
      cleanup_unused_versions(@function_name) if delete_unreferenced_versions
    end

    def delete
      lambda_details = retrieve_lambda_details
      if lambda_details.nil?
        puts 'No Lambda to delete.'
      else
        @lambda_client.delete_function(function_name: @function_name)
        puts "Lambda #{@function_name} and all Versions & Aliases have been deleted."
      end
    end

    private

    def retrieve_lambda_details
      lambda_details = nil
      begin
        lambda_details = @lambda_client.get_function(function_name: @function_name).configuration
      rescue Aws::Lambda::Errors::ResourceNotFoundException
        puts "Lambda #{@function_name} does not exist."
      end
      lambda_details
    end

    def load_deployment_package_blob
      unless File.exist?(@path_to_zip_file)
        raise ArgumentException, "Deployment Package Zip File does not exist: #{@path_to_zip_file}!"
      end
      File.open(@path_to_zip_file, 'r') { |deployment_package_blob| return deployment_package_blob }
    end

    def create_lambda(zip_blob)
      puts "Creating New Lambda Function: #{@function_name}...."
      puts "Runtime Engine: #{@runtime}, Timeout: #{@timeout}, Memory Size: #{@memory_size}."

      unless @subnet_ids.empty? && @security_group_ids.empty?
        vpc_configuration = {
          subnet_ids: @subnet_ids,
          security_group_ids: @security_group_ids
        }
        puts "With VPC Configuration: Subnets: #{@subnet_ids}, Security Groups: #{@security_group_ids}"
      end

      lambda_version = @lambda_client.create_function(
        function_name: @function_name, runtime: @runtime, role: @role_arn, handler: @handler,
        code: { zip_file: zip_blob }, description: @description, timeout: @timeout, memory_size: @memory_size,
        vpc_config: vpc_configuration
      ).version
      puts "Successfully created Lambda: #{@function_name}!"
      lambda_version
    end

    def update_lambda_config
      puts "Updating Lambda Config for #{@function_name}..."
      puts "Runtime Engine: #{@runtime}, Timeout: #{@timeout}, Memory Size: #{@memory_size}."
      unless @subnet_ids.empty? && @security_group_ids.empty?
        vpc_configuration = {
          subnet_ids: @subnet_ids,
          security_group_ids: @security_group_ids
        }
        puts "With VPC Configuration: Subnets: #{@subnet_ids}, Security Groups: #{@security_group_ids}"
      end

      @lambda_client.update_function_configuration(
        function_name: @function_name, role: @role_arn, handler: @handler, description: @description, timeout: @timeout,
        memory_size: @memory_size, vpc_config: vpc_configuration, runtime: @runtime
      )

      puts "Successfully updated Lambda configuration for #{@function_name}"
    end

    def update_lambda_code(zip_blob)
      puts "Updating Lambda Code for #{@function_name}...."

      function_version = @lambda_client.update_function_code(function_name: @function_name, zip_file: zip_blob).version

      puts "Successully updated Lambda #{@function_name} code to version: #{function_version}"
    end

    ##
    # Creates an alias for a given lambda function version.
    #
    # *Arguments*
    # [function_name]    The lambda function name for which the alias should be created.
    # [func_version]    The lambda function versino to which the alias should point.
    # [alias_name]      The name of the alias, matching the LambdaWrap environment concept.
    def create_alias(function_name, func_version, alias_name)
      # create or update alias
      func_alias = @client.list_aliases(function_name: function_name).aliases.select { |a| a.name == alias_name }.first
      a = if !func_alias
            @client.create_alias(
              function_name: function_name, name: alias_name, function_version: func_version,
              description: 'created by an automated script'
            ).data
          else
            @client.update_alias(
              function_name: function_name, name: alias_name, function_version: func_version,
              description: 'updated by an automated script'
            ).data
          end
      puts "Created Alias: #{alias_name} for Lambda: #{function_name} v#{func_version}."
      a
    end

    def remove_alias(lambda_name, alias_name)
      puts "Deleting Alias: #{alias_name} for #{lambda_name}"
      @lambda_client.delete_alias(function_name: lambda_name, name: alias_name)
    end

    def cleanup_unused_versions(lambda_name)
      puts "Cleaning up unused function versions for #{lambda_name}."
      function_versions = []
      function_versions.concat(retrieve_all_function_versions(lambda_name))
      return if function_versions.empty?
      function_versions_used_by_aliases = []
      function_versions_used_by_aliases.concat(retrieve_function_versions_used_in_aliases(lambda_name))
      function_versions_to_be_deleted = function_versions - function_versions_used_by_aliases
      return if function_versions_to_be_deleted.empty?
      function_versions_to_be_deleted.each do |version|
        puts "Deleting function version: #{version}."
        @lambda_client.delete_function(function_name: lambda_name, qualifier: version)
      end
      puts "Cleaned up #{function_versions_to_be_deleted.length}."
    end

    def retrieve_all_function_versions(lambda_name)
      function_versions = []
      versions_by_function_response = @lambda_client.list_versions_by_function(function_name: lambda_name)
      function_versions.concat(
        versions_by_function_response[:versions].map { |func_version| func_version[:version] }
      )

      while !versions_by_function_response[:next_marker].nil? && !versions_by_function_response[:next_marker].empty?
        versions_by_function_response = @lambda_client.list_versions_by_function(
          function_name: lambda_name, marker: versions_by_function_response[:next_marker]
        )
        function_versions.concat(
          versions_by_function_response[:versions].map { |func_version| func_version[:version] }
        )
      end
      function_versions
    end

    def retrieve_function_versions_used_in_aliases(lambda_name)
      function_versions_with_aliases = Set.new []
      versions_with_aliases_response = @lambda_client.list_aliases(function_name: lambda_name)
      return [] if versions_with_aliases_response.aliases.empty?
      function_versions_with_aliases = function_versions_with_aliases.merge(
        versions_with_aliases_response[:aliases].map(&:function_version)
      )
      while !versions_with_aliases_response[:next_marker].nil? && !versions_with_aliases_response[:next_marker].empty?
        versions_with_aliases_response = @lambda_client.list_aliases(
          function_name: lambda_name, next_marker: versions_with_aliases_response[:next_marker]
        )
        function_versions_with_aliases = function_versions_with_aliases.merge(
          versions_with_aliases_response[:aliases].map(&:function_version)
        )
      end
      function_versions_with_aliases.to_a
    end
  end
end
