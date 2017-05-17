require 'set'
require 'pathname'

module LambdaWrap
  # Lambda Manager class.
  # Front loads the configuration to the constructor so that the developer can be more declarative with configuration
  # and deployments.
  # @since 1.0
  class Lambda < AwsService
    # Initializes a Lambda Manager. Frontloaded configuration.
    #
    # @param [Hash] options The Configuration for the Lambda
    # @option options [String] :lambda_name The name you want to assign to the function you are uploading. The function
    #  names appear in the console and are returned in the ListFunctions API. Function names are used to specify
    #  functions to other AWS Lambda API operations, such as Invoke. Note that the length constraint applies only to
    #  the ARN. If you specify only the function name, it is limited to 64 characters in length.
    # @option options [String] :handler The function within your code that Lambda calls to begin execution.
    # @option options [String] :role_arn The Amazon Resource Name (ARN) of the IAM role that Lambda assumes when it
    #  executes your function to access any other Amazon Web Services (AWS) resources.
    # @option options [String] :path_to_zip_file The absolute path to the Deployment Package zip file
    # @option options [String] :runtime The runtime environment for the Lambda function you are uploading.
    # @option options [String] :description ('Deployed with LambdaWrap') A short, user-defined function description.
    #  Lambda does not use this value. Assign a meaningful description as you see fit.
    # @option options [Integer] :timeout (30) The function execution time at which Lambda should terminate the function.
    # @option options [Integer] :memory_size (128) The amount of memory, in MB, your Lambda function is given. Lambda
    #  uses this memory size to infer the amount of CPU and memory allocated to your function. The value must be a
    #  multiple of 64MB. Minimum: 128, Maximum: 1536.
    # @option options [Array<String>] :subnet_ids ([]) If your Lambda function accesses resources in a VPC, you provide
    #  this parameter identifying the list of subnet IDs. These must belong to the same VPC. You must provide at least
    #  one security group and one subnet ID to configure VPC access.
    # @option options [Array<String>] :security_group_ids ([]) If your Lambda function accesses resources in a VPC, you
    #  provide this parameter identifying the list of security group IDs. These must belong to the same VPC. You must
    #  provide at least one security group and one subnet ID.
    # @option options [Boolean] :delete_unreferenced_versions (true) Option to delete any Lambda Function Versions upon
    #  deployment that do not have an alias pointing to them.
    def initialize(options)
      defaults = {
        description: 'Deployed with LambdaWrap', subnet_ids: [], security_group_ids: [], timeout: 30, memory_size: 128,
        delete_unreferenced_versions: true
      }
      options_with_defaults = options.reverse_merge(defaults)

      unless (options_with_defaults[:lambda_name]) && (options_with_defaults[:lambda_name].is_a? String)
        raise ArgumentError, 'lambda_name must be provided (String)!'
      end
      @lambda_name = options_with_defaults[:lambda_name]

      unless (options_with_defaults[:handler]) && (options_with_defaults[:handler].is_a? String)
        raise ArgumentError, 'handler must be provided (String)!'
      end
      @handler = options_with_defaults[:handler]

      unless (options_with_defaults[:role_arn]) && (options_with_defaults[:role_arn].is_a? String)
        raise ArgumentError, 'role_arn must be provided (String)!'
      end
      @role_arn = options_with_defaults[:role_arn]

      unless (options_with_defaults[:path_to_zip_file]) && (options_with_defaults[:path_to_zip_file].is_a? String)
        raise ArgumentError, 'path_to_zip_file must be provided (String)!'
      end
      @path_to_zip_file = options_with_defaults[:path_to_zip_file]

      unless (options_with_defaults[:runtime]) && (options_with_defaults[:runtime].is_a? String)
        raise ArgumentError, 'runtime must be provided (String)!'
      end

      case options_with_defaults[:runtime]
      when 'nodejs' then raise ArgumentError, 'AWS Lambda Runtime NodeJS v0.10.42 is deprecated as of April 2017. \
        Please see: https://forums.aws.amazon.com/ann.jspa?annID=4142'
      when 'nodejs4.3', 'nodejs6.10', 'java8', 'python2.7', 'python3.6', 'dotnetcore1.0', 'nodejs4.3-edge'
        @runtime = options_with_defaults[:runtime]
      else
        raise ArgumentError, "Invalid Runtime specified: #{options_with_defaults[:runtime]}. Only accepts: \
nodejs4.3, nodejs6.10, java8, python2.7, python3.6, dotnetcore1.0, or nodejs4.3-edge"
      end

      @description = options_with_defaults[:description]

      @timeout = options_with_defaults[:timeout]

      unless (options_with_defaults[:memory_size] % 64).zero? && (options_with_defaults[:memory_size] >= 128) &&
             (options_with_defaults[:memory_size] <= 1536)
        raise ArgumentError, 'Invalid Memory Size.'
      end
      @memory_size = options_with_defaults[:memory_size]

      # VPC
      if options_with_defaults[:subnet_ids].empty? ^ options_with_defaults[:security_group_ids].empty?
        raise ArgumentError, 'Must supply values for BOTH Subnet Ids and Security Group ID if VPC is desired.'
      end
      unless options_with_defaults[:subnet_ids].empty?
        @vpc_configuration = {
          subnet_ids: options_with_defaults[:subnet_ids],
          security_group_ids: options_with_defaults[:security_group_ids]
        }
      end

      @delete_unreferenced_versions = options_with_defaults[:delete_unreferenced_versions]
    end

    # Deploys the Lambda to the specified Environment. Creates a Lambda Function if one didn't exist.
    # Updates the Lambda's configuration, Updates the Lambda's Code, publishes a new version, and creates
    # an alias that points to the newly published version. If the @delete_unreferenced_versions option
    # is enabled, all Lambda Function versions that don't have an alias pointing to them will be deleted.
    #
    # @param environment_options [LambdaWrap::Environment] The target Environment to deploy
    # @param client [Aws::Lambda::Client] Client to use with SDK. Should be passed in by the API class.
    # @param region [String] AWS Region string. Should be passed in by the API class.
    def deploy(environment_options, client, region = 'AWS_REGION')
      super

      puts "Deploying Lambda: #{@lambda_name} to Environment: #{environment_options.name}"

      unless File.exist?(@path_to_zip_file)
        raise ArgumentError, "Deployment Package Zip File does not exist: #{@path_to_zip_file}!"
      end

      lambda_details = retrieve_lambda_details

      if lambda_details.nil?
        function_version = create_lambda
      else
        update_lambda_config
        function_version = update_lambda_code
      end

      create_alias(function_version, environment_options.name, environment_options.description)

      cleanup_unused_versions if @delete_unreferenced_versions

      puts "Lambda: #{@lambda_name} successfully deployed!"
      true
    end

    # Tearsdown an Environment. Deletes an alias with the same name as the environment. Deletes
    # Unreferenced Lambda Function Versions if the option was specified.
    #
    # @param environment_options [LambdaWrap::Environment] The target Environment to teardown.
    # @param client [Aws::Lambda::Client] Client to use with SDK. Should be passed in by the API class.
    # @param region [String] AWS Region string. Should be passed in by the API class.
    def teardown(environment_options, client, region = 'AWS_REGION')
      super
      remove_alias(environment_options.name)
      cleanup_unused_versions if @delete_unreferenced_versions
      true
    end

    # Deletes the Lambda Object with associated versions, code, configuration, and aliases.
    #
    # @param client [Aws::Lambda::Client] Client to use with SDK. Should be passed in by the API class.
    # @param region [String] AWS Region string. Should be passed in by the API class.
    def delete(client, region = 'AWS_REGION')
      super
      puts "Deleting all versions and aliases for Lambda: #{@lambda_name}"
      lambda_details = retrieve_lambda_details
      if lambda_details.nil?
        puts 'No Lambda to delete.'
      else
        @client.delete_function(function_name: @lambda_name)
        puts "Lambda #{@lambda_name} and all Versions & Aliases have been deleted."
      end
      true
    end

    def to_s
      return @lambda_name if @lambda_name && @lambda_name.is_a?(String)
      super
    end

    private

    def retrieve_lambda_details
      lambda_details = nil
      begin
        lambda_details = @client.get_function(function_name: @lambda_name).configuration
      rescue Aws::Lambda::Errors::ResourceNotFoundException, Aws::Lambda::Errors::NotFound
        puts "Lambda #{@lambda_name} does not exist."
      end
      lambda_details
    end

    def create_lambda
      puts "Creating New Lambda Function: #{@lambda_name}...."
      puts "Runtime Engine: #{@runtime}, Timeout: #{@timeout}, Memory Size: #{@memory_size}."

      lambda_version = @client.create_function(
        function_name: @lambda_name, runtime: @runtime, role: @role_arn, handler: @handler,
        code: { zip_file: @path_to_zip_file }, description: @description, timeout: @timeout, memory_size: @memory_size,
        vpc_config: @vpc_configuration, publish: true
      ).version
      puts "Successfully created Lambda: #{@lambda_name}!"
      lambda_version
    end

    def update_lambda_config
      puts "Updating Lambda Config for #{@lambda_name}..."
      puts "Runtime Engine: #{@runtime}, Timeout: #{@timeout}, Memory Size: #{@memory_size}."
      if @vpc_configuration
        puts "With VPC Configuration: Subnets: #{@vpc_configuration[:subnet_ids]}, Security Groups: \
#{@vpc_configuration[:security_group_ids]}"
      end

      @client.update_function_configuration(
        function_name: @lambda_name, role: @role_arn, handler: @handler, description: @description, timeout: @timeout,
        memory_size: @memory_size, vpc_config: @vpc_configuration, runtime: @runtime
      )

      puts "Successfully updated Lambda configuration for #{@lambda_name}"
    end

    def update_lambda_code
      puts "Updating Lambda Code for #{@lambda_name}...."

      response = @client.update_function_code(
        function_name: @lambda_name,
        zip_file: File.open(@path_to_zip_file, 'rb').read,
        publish: true
      )

      puts "Successully updated Lambda #{@lambda_name} code to version: #{response.version}"
      response.version
    end

    def create_alias(func_version, alias_name, alias_description)
      if alias_exist?(alias_name)
        @client.update_alias(
          function_name: @lambda_name, name: alias_name, function_version: func_version,
          description: alias_description || 'Alias managed by LambdaWrap'
        )
      else
        @client.create_alias(
          function_name: @lambda_name, name: alias_name, function_version: func_version,
          description: alias_description || 'Alias managed by LambdaWrap'
        )
      end
      puts "Created Alias: #{alias_name} for Lambda: #{@lambda_name} v#{func_version}."
    end

    def remove_alias(alias_name)
      puts "Deleting Alias: #{alias_name} for #{@lambda_name}"
      @client.delete_alias(function_name: @lambda_name, name: alias_name)
    end

    def cleanup_unused_versions
      puts "Cleaning up unused function versions for #{@lambda_name}."
      function_versions_to_be_deleted = retrieve_all_function_versions -
                                        retrieve_function_versions_used_in_aliases

      return if function_versions_to_be_deleted.empty?

      function_versions_to_be_deleted.each do |version|
        puts "Deleting function version: #{version}."
        @client.delete_function(function_name: @lambda_name, qualifier: version)
      end

      puts "Cleaned up #{function_versions_to_be_deleted.length} unused versions."
    end

    def retrieve_all_function_versions
      function_versions = []
      response = nil
      loop do
        response =
          if !response || response.next_marker.nil? || response.next_marker.empty?
            @client.list_versions_by_function(function_name: @lambda_name)
          else
            @client.list_versions_by_function(function_name: @lambda_name, marker: response.next_marker)
          end
        function_versions.concat(response.versions.map(&:version))
        if response.next_marker.nil? || response.next_marker.empty?
          return function_versions.reject { |v| v == '$LATEST' }
        end
      end
    end

    def retrieve_all_aliases
      aliases = []
      response = nil
      loop do
        response = invoke_client_method_with_optional_marker(response, :list_aliases)
        aliases.concat(response.aliases)
        return aliases if response.aliases.empty? || response.next_marker.nil? || response.next_marker.empty?
      end
    end

    def retrieve_function_versions_used_in_aliases
      function_versions_with_aliases = Set.new []
      function_versions_with_aliases.merge(retrieve_all_aliases.map(&:function_version)).to_a
    end

    def alias_exist?(alias_name)
      retrieve_all_aliases.detect { |a| a.name == alias_name }
    end

    def invoke_client_method_with_optional_marker(response, method_symbol)
      if !response || response.next_marker.nil? || response.next_marker.empty?
        @client.send(method_symbol, function_name: @lambda_name)
      else
        @client.send(method_symbol, function_name: @lambda_name, marker: response.next_marker)
      end
    end
  end
end
