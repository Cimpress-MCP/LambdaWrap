require 'active_support/core_ext/hash'

module LambdaWrap
  # The ApiGateway class simplifies creation, deployment, and management of API Gateway objects.
  # The specification for the API MUST be detailed in a provided Open API Formatted file (fka Swagger).
  class ApiGateway
    attr_reader :specification
    attr_reader :import_mode

    # Initializes the APIGateway Manager Object. A significant majority of the configuration of your
    # API should be configured through your Swagger File (e.g. Integrations, API Name, Version).
    #
    # @param [Hash] options The Options initialize the API Gateway Manager with.
    # @options options [String] :swagger_file_path File path the Swagger File to load and parse.
    # @options options [String] :import_mode How the API Gateway Object will handle updates.
    #  Accepts 'overwrite' and 'merge'. Defaults to overwrite.
    def initialize(options)
      options_with_defaults = options.reverse_merge(import_mode: 'overwrite')
      @specification = extract_specification(options_with_defaults[:swagger_file_path])
      @api_name = @specification['info']['title']
      @api_version = @specification['info']['version']
      @import_mode = options_with_defaults[:import_mode]
    end

    # Deploys the API Gateway Object to a specified environment
    #
    # @param environment_options [LambdaWrap::Environment] The environment to deploy
    def deploy(environment_options)
      super
      client_guard
      @stage_variables = environment_options.variables || {}
      @stage_variables.store('environment', environment_options.name)

      api_id = get_existing_rest_api(@api_name)
      service_response = nil
      if api_id.nil?
        service_response = @api_gateway_client.import_rest_api(fail_on_warnings: false, body: @specification)
      else
        service_response = @api_gateway_client.put_rest_api(
          fail_on_warnings: false, mode: @import_mode, rest_api_id:
          api_id, body: @specification
        )
      end
      if service_response.nil? && service_response.id.nil?
        raise "Failed to create API gateway with name #{@api_name}"
      end

      if api_id.nil?
        "Created API Gateway Object: #{@api_name} having id #{service_response.id}"
      else
        "Updated API Gateway Object: #{@api_name} having id #{service_response.id}"
      end

      create_stage(service_response.id, environment_options)

      service_uri = "https://#{service_response.id}.execute-api.\
        #{@region}.amazonaws.com/#{environment_options.name}/"

      puts "Service deployed at #{service_uri}"

      service_uri
    end

    # Tearsdown environment for API Gateway. Deletes stage.
    #
    # @param environment_options [LambdaWrap::Environment] The environment to teardown.
    def teardown(environment_options)
      super
      client_guard
      api_id = get_existing_rest_api(@api_name)
      if api_id
        delete_stage(api_id, environment_options.name)
      else
        puts "API Gateway Object #{@api_name} not found. No environment to tear down."
      end
    end

    # Deletes all stages and API Gateway object.
    def delete
      client_guard
      api_id = get_existing_rest_api(@api_name)
      if api_id
        @api_gateway_client.delete_rest_api(rest_api_id: api_id)
        puts "Deleted API: #{@api_name} ID:#{api_id}"
      else
        puts "API Gateway Object #{@api_name} not found. Nothing to delete."
      end
    end

    private

    def delete_stage(api_id, env)
      @api_gateway_client.delete_stage(rest_api_id: api_id, stage_name: env)
      puts 'Deleted API gateway stage ' + env
    rescue Aws::APIGateway::Errors::NotFoundException
      puts 'API Gateway stage ' + env + ' does not exist. Nothing to delete.'
    end

    def create_stage(api_id, environment_options)
      deployment_description = "Deploying API #{@api_name} v#{@api_version}\
        to Environment:#{environment_options.name}"
      stage_description = "#{environment_options.name} - #{environment_options.description}"
      @api_gateway_client.create_deployment(
        rest_api_id: api_id, stage_name: environment_options.name,
        stage_description: stage_description, description: deployment_description,
        cache_cluster_enabled: false, variables: environment_options.variables
      )
    end

    def extract_specification(file_path)
      spec = load_file(file_path)
      raise ArgumentError, 'LambdaWrap only supports swagger v2.0' unless spec['swagger'] == '2.0'
      spec
    end

    def get_existing_rest_api(api_name)
      apis = @api_gateway_client.get_rest_apis(limit: 500).data
      api = apis.items.select { |a| a.name == api_name }.first

      return api.id if api
      # nil is returned otherwise
    end

    def client_guard
      raise Exception, 'APIGateway client not initialized.' unless @api_gateway_client
    end
  end
end
