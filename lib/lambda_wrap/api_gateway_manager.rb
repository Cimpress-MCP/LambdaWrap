module LambdaWrap
  # The ApiGateway class simplifies creation, deployment, and management of API Gateway objects.
  # The specification for the API MUST be detailed in a provided Open API Formatted file (fka Swagger).
  #
  # @!attribute [r] specification
  #   @return [Hash] The Swagger spec parsed into a Hash
  #
  # @since 1.0
  class ApiGateway < AwsService
    attr_reader :specification

    # Initializes the APIGateway Manager Object. A significant majority of the configuration of your
    # API should be configured through your Swagger File (e.g. Integrations, API Name, Version).
    #
    # @param [Hash] options The Options initialize the API Gateway Manager with.
    # @option options [String] :path_to_swagger_file File path the Swagger File to load and parse.
    # @option options [String] :import_mode (overwrite) How the API Gateway Object will handle updates.
    #  Accepts <tt>overwrite</tt> and <tt>merge</tt>.
    def initialize(options)
      options_with_defaults = options.reverse_merge(import_mode: 'overwrite')
      @path_to_swagger_file = options_with_defaults[:path_to_swagger_file]
      @specification = extract_specification(@path_to_swagger_file)
      @api_name = @specification['info']['title']
      @api_version = @specification['info']['version']
      @import_mode = options_with_defaults[:import_mode]
    end

    # Deploys the API Gateway Object to a specified environment
    #
    # @param environment_options [LambdaWrap::Environment] The environment to deploy
    # @param client [Aws::APIGateway::Client] Client to use with SDK. Should be passed in by the API class.
    # @param region [String] AWS Region string. Should be passed in by the API class.
    def deploy(environment_options, client, region = 'AWS_REGION')
      super
      puts "Deploying API: #{@api_name} to Environment: #{environment_options.name}"
      @stage_variables = environment_options.variables || {}
      @stage_variables.store('environment', environment_options.name)

      api_id = get_id_for_api(@api_name)
      service_response =
        if api_id
          options = {
            fail_on_warnings: false, mode: @import_mode, rest_api_id:
            api_id, body: File.binread(@path_to_swagger_file)
          }
          @client.put_rest_api(options)
        else
          options = {
            fail_on_warnings: false,
            body: File.binread(@path_to_swagger_file)
          }
          @client.import_rest_api(options)
        end

      if service_response.nil? || service_response.id.nil?
        raise "Failed to create API gateway with name #{@api_name}"
      end

      if api_id
        "Created API Gateway Object: #{@api_name} having id #{service_response.id}"
      else
        "Updated API Gateway Object: #{@api_name} having id #{service_response.id}"
      end

      create_stage(service_response.id, environment_options)

      service_uri = "https://#{service_response.id}.execute-api.#{@region}.amazonaws.com/#{environment_options.name}/"

      puts "API: #{@api_name} deployed at #{service_uri}"

      service_uri
    end

    # Tearsdown environment for API Gateway. Deletes stage.
    #
    # @param environment_options [LambdaWrap::Environment] The environment to teardown.
    # @param client [Aws::APIGateway::Client] Client to use with SDK. Should be passed in by the API class.
    # @param region [String] AWS Region string. Should be passed in by the API class.
    def teardown(environment_options, client, region = 'AWS_REGION')
      super
      api_id = get_id_for_api(@api_name)
      if api_id
        delete_stage(api_id, environment_options.name)
      else
        puts "API Gateway Object #{@api_name} not found. No environment to tear down."
      end
      true
    end

    # Deletes all stages and API Gateway object.
    # @param client [Aws::APIGateway::Client] Client to use with SDK. Should be passed in by the API class.
    # @param region [String] AWS Region string. Should be passed in by the API class.
    def delete(client, region = 'AWS_REGION')
      super
      api_id = get_id_for_api(@api_name)
      if api_id
        options = {
          rest_api_id: api_id
        }
        @client.delete_rest_api(options)
        puts "Deleted API: #{@api_name} ID:#{api_id}"
      else
        puts "API Gateway Object #{@api_name} not found. Nothing to delete."
      end
      true
    end

    def to_s
      return @api_name if @api_name && @api_name.is_a?(String)
      super
    end

    private

    def delete_stage(api_id, env)
      options = {
        rest_api_id: api_id, stage_name: env
      }
      @client.delete_stage(options)
      puts 'Deleted API gateway stage ' + env
    rescue Aws::APIGateway::Errors::NotFoundException
      puts "API Gateway stage #{env} does not exist. Nothing to delete."
    end

    def create_stage(api_id, environment_options)
      deployment_description = "Deploying API #{@api_name} v#{@api_version}\
        to Environment:#{environment_options.name}"
      stage_description = "#{environment_options.name} - #{environment_options.description}"
      options = {
        rest_api_id: api_id, stage_name: environment_options.name,
        stage_description: stage_description, description: deployment_description,
        cache_cluster_enabled: false, variables: environment_options.variables
      }
      @client.create_deployment(options)
    end

    def extract_specification(file_path)
      unless File.exist?(file_path)
        raise ArgumentError, "Open API Spec (Swagger) File does not exist: #{file_path}!"
      end
      spec = Psych.load_file(file_path)
      raise ArgumentError, 'LambdaWrap only supports swagger v2.0' unless spec['swagger'] == '2.0'
      raise ArgumentError, 'Invalid Title field in the OAPISpec' unless spec['info']['title'] =~ /[A-Za-z0-9]{1,1024}/
      spec
    end

    def get_id_for_api(api_name)
      response = nil
      loop do
        options = {
          limit: 500
        }
        options[:position] = response.position unless !response || response.position.nil?
        response = @client.get_rest_apis(options)
        api = response.items.detect { |item| item.name == api_name }
        return api.id if api
        return if response.items.empty? || response.position.nil? || response.position.empty?
      end
    end
  end
end
