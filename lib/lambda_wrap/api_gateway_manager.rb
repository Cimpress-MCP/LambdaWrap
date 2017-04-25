require 'aws-sdk'
require 'yaml'
require 'active_support/core_ext/hash'

module LambdaWrap
  # The ApiGatewayManager simplifies downloading the aws-apigateway-importer binary,
  # importing a {swagger configuration}[http://swagger.io], and managing API Gateway stages.
  # Added functionality to create APIGateway deom Swagger file. Thsi API is useful for gateway's having
  # custom authorization.

  # Note: The concept of an environment of the LambdaWrap gem matches a stage in AWS ApiGateway terms.
  class ApiGatewayManager
    #
    # The constructor does some basic setup
    # * Validating basic AWS configuration
    # * Creating the underlying client to interact with the AWS SDK.
    # * Defining the temporary path of the api-gateway-importer jar file
    def initialize
      # AWS api gateway client
      @client = Aws::APIGateway::Client.new
      # path to apigateway-importer jar
      @jarpath = File.join(Dir.tmpdir, 'aws-apigateway-importer-1.0.3-SNAPSHOT-jar-with-dependencies.jar')
      @versionpath = File.join(Dir.tmpdir, 'aws-apigateway-importer-1.0.3-SNAPSHOT-jar-with-dependencies.s3version')
    end

    ##
    # Downloads the aws-apigateway-importer jar from an S3 bucket.
    # This is a workaround since aws-apigateway-importer does not provide a binary.
    # Once a binary is available on the public internet, we'll start using this instead
    # of requiring users of this gem to upload their custom binary to an S3 bucket.
    #
    # *Arguments*
    # [s3_bucket]  An S3 bucket from where the aws-apigateway-importer binary can be downloaded.
    # [s3_key]  The path (key) to the aws-apigateay-importer binary on the s3 bucket.
    def download_apigateway_importer(s3_bucket, s3_key)
      s3 = Aws::S3::Client.new

      # current version
      current_s3_version = File.open(@versionpath, 'rb').read if File.exist?(@versionpath)

      # online s3 version
      desired_s3_version = s3.head_object(bucket: s3_bucket, key: s3_key).version_id

      # compare local with remote version
      if current_s3_version != desired_s3_version || !File.exist?(@jarpath)
        puts "Downloading aws-apigateway-importer jar with S3 version #{desired_s3_version}"
        s3.get_object(response_target: @jarpath, bucket: s3_bucket, key: s3_key)
        File.write(@versionpath, desired_s3_version)
      end
    end

    ##
    # Sets up the API gateway by searching whether the API Gateway already exists
    # and updates it with the latest information from the swagger file.
    #
    # *Arguments*
    # [api_name]  The name of the API to which the swagger file should be applied to.
    # [env]  The environment where it should be published (which is matching an API gateway stage)
    # [swagger_file]  A handle to a swagger file that should be used by aws-apigateway-importer
    # [api_description]  The description of the API to be displayed.
    # [stage_variables]  A Hash of stage variables to be deployed with the stage. Adds an 'environment' by default.
    # [region]  A string representing the region to deploy the API. Defaults to what is set as an environment variable.
    def setup_apigateway(api_name, env, swagger_file, api_description = 'Deployed with LambdaWrap',
                         stage_variables = {}, region = ENV['AWS_REGION'])
      # ensure API is created
      api_id = get_existing_rest_api(api_name)
      api_id = setup_apigateway_create_rest_api(api_name, api_description) unless api_id

      # create resources
      setup_apigateway_create_resources(api_id, swagger_file, region)

      # create stages
      stage_variables.store('environment', env)
      create_stages(api_id, env, stage_variables)

      # return URI of created stage
      "https://#{api_id}.execute-api.#{region}.amazonaws.com/#{env}/"
    end

    ##
    # Shuts down an environment from the API Gateway. This basically deletes the stage
    # from the API Gateway, but does not delete the API Gateway itself.
    #
    # *Argument*
    # [api_name]  The name of the API where the environment should be shut down.
    # [env]  The environment (matching an API Gateway stage) to shutdown.
    def shutdown_apigateway(api_name, env)
      api_id = get_existing_rest_api(api_name)
      delete_stage(api_id, env)
    end

    ##
    # Gets the ID of an existing API Gateway api, or nil if it doesn't exist
    #
    # *Arguments*
    # [api_name]  The name of the API to be checked for existance
    def get_existing_rest_api(api_name)
      apis = @client.get_rest_apis(limit: 500).data
      api = apis.items.select { |a| a.name == api_name }.first

      return api.id if api
      # nil is returned otherwise
    end

    ##
    # Creates the API with a given name using the SDK and returns the id
    #
    # *Arguments*
    # [api_name]  A String representing the name of the API Gateway Object to be created
    # [api_description]  A String representing the description of the API
    def setup_apigateway_create_rest_api(api_name, api_description)
      puts 'Creating API with name ' + api_name
      api = @client.create_rest_api(name: api_name, description: api_description)
      api.id
    end

    ##
    # Invokes the aws-apigateway-importer jar with the required parameter
    #
    # *Arguments*
    # [api_id]  The AWS ApiGateway id where the swagger file should be applied to.
    # [swagger_file]  The handle to a swagger definition file that should be imported into API Gateway
    # [region]  A string representing the target region to deploy the API
    def setup_apigateway_create_resources(api_id, swagger_file, region)
      raise 'API ID not provided' unless api_id

      cmd = "java -jar #{@jarpath} --update #{api_id} --region #{region} #{swagger_file}"
      raise 'API gateway not created' unless system(cmd)
    end

    ##
    # Creates a stage of the currently set resources
    #
    # *Arguments*
    # [api_id]  The AWS ApiGateway id where the stage should be created at.
    # [env]  The environment (which matches the stage in API Gateway) to create.
    # [stage_variables]  A Hash of stage variables to deploy with the stage
    def create_stages(api_id, env, stage_variables)
      deployment_description = 'Deployment of service to ' + env
      deployment = @client.create_deployment(
        rest_api_id: api_id, stage_name: env, cache_cluster_enabled: false, description: deployment_description,
        variables: stage_variables
      ).data
      puts deployment
    end

    ##
    # Deletes a stage of the API Gateway
    #
    # *Arguments*
    # [api_id]  The AWS ApiGateway id from which the stage should be deleted from.
    # [env]The environment (which matches the stage in API Gateway) to delete.
    def delete_stage(api_id, env)
      @client.delete_stage(rest_api_id: api_id, stage_name: env)
      puts 'Deleted API gateway stage ' + env
    rescue Aws::APIGateway::Errors::NotFoundException
      puts 'API Gateway stage ' + env + ' does not exist. Nothing to delete.'
    end

    ##
    # Generate or Update the API Gateway by using the swagger file and the SDK importer
    #
    # *Arguments*
    # [api_name] API Gateway name
    # [local_swagger_file] Path of the local swagger file
    # [env] Environment identifier
    # [stage_variables] hash of stage variables
    def setup_apigateway_by_swagger_file(api_name, local_swagger_file, env, stage_variables = {})
      # If API gateway with the name is already present then update it else create a new one
      api_id = get_existing_rest_api(api_name)
      swagger_file_content = File.read(local_swagger_file)

      gateway_response = nil
      if api_id.nil?
        # Create a new APIGateway
        gateway_response =  @client.import_rest_api(fail_on_warnings: false, body: swagger_file_content)
      else
        # Update the exsiting APIgateway. By Merge the exsisting gateway will be merged with the new
        # one supplied in the Swagger file.
        gateway_response =  @client.put_rest_api(rest_api_id: api_id, mode: 'merge', fail_on_warnings: false,
                                                 body: swagger_file_content)
      end

      raise "Failed to create API gateway with name #{api_name}" if gateway_response.nil? && gateway_response.id.nil?

      if api_id.nil?
        puts "Created api gateway #{api_name} having id #{gateway_response.id}"
      else
        puts "Updated api gateway #{api_name} having id #{gateway_response.id}"
      end

      # Deploy the service
      stage_variables.store('environment', env)
      create_stages(gateway_response.id, env, stage_variables)

      service_uri = "https://#{gateway_response.id}.execute-api.#{ENV['AWS_REGION']}.amazonaws.com/#{env}/"
      puts "Service deployed at #{service_uri}"

      service_uri
    end

    private :get_existing_rest_api, :setup_apigateway_create_rest_api, :setup_apigateway_create_resources,
            :create_stages, :delete_stage
  end

  class ApiGateway
    attr_reader :specification
    attr_reader :import_mode

    def initialize(options)
      options_with_defaults = options.reverse_merge(import_mode: 'overwrite')
      @specification = extract_specification(options_with_defaults[:swagger_file_path])
      @import_mode = options_with_defaults[:import_mode]
    end

    def deploy(options)
      @stage_variables = options[:environment][:variables] || {}
      @stage_variables.store('environment', options.environment.name)

      api_id = get_existing_rest_api(@specification[:info][:title])
      service_response = nil
      if api_id.nil?
        service_response = @api_gateway_client.import_rest_api(fail_on_warnings: false, body: @specification)
      else
        service_response = @api_gateway_client.put_rest_api(fail_on_warnings: false, mode: @import_mode, rest_api_id:
          api_id, body: @specification)
      end
      if gateway_response.nil? && gateway_response.id.nil?
        raise "Failed to create API gateway with name #{@specification[:info][:title]}"
      end

      if api_id.nil?
        "Created API Gateway Object: #{@specification[:info][:title]} having id #{service_response.id}"
      else
        "Updated API Gateway Object: #{@specification[:info][:title]} having id #{service_response.id}"
      end
    end

    ##
    # Gets the ID of an existing API Gateway api, or nil if it doesn't exist
    #
    # *Arguments*
    # [api_name]  The name of the API to be checked for existance
    def get_existing_rest_api(api_name)
      apis = @api_gateway_client.get_rest_apis(limit: 500).data
      api = apis.items.select { |a| a.name == api_name }.first

      return api.id if api
      # nil is returned otherwise
    end

    private

    def extract_specification(file_path)
      spec = load_file(file_path)
      raise ArgumentError, 'LambdaWrap only supports swagger v2.0' unless spec['swagger'] == '2.0'
    end
  end
end
