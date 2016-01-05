require 'aws-sdk'
require_relative 'aws_setup'

module LambdaWrap
	
	class ApiGatewayManager
		
		def initialize()
			AwsSetup.new.validate()
			# AWS lambda client
			@client = Aws::APIGateway::Client.new()
		end
		
		def setup_apigateway(api_name, env)
			
			# ensure API is created
			api_id = get_existing_rest_api(api_name)
			api_id = setup_apigateway_create_rest_api(api_name) if !api_id
			
			# create resources
			setup_apigateway_create_resources(api_id)
			
			# create stages
			create_stages(api_id, env)
			
			# return URI of created stage
			return "https://#{api_id}.execute-api.#{ENV['AWS_REGION']}.amazonaws.com/#{env}/"
			
		end
		
		def shutdown_apigateway(api_name, env)
		
			api_id = get_existing_rest_api(api_name)
			delete_stage(api_id, env)
			
		end
		
		def get_existing_rest_api(api_name)
			
			apis = @client.get_rest_apis({limit: 500}).data
			api = apis.items.select{ |api| api.name == api_name}.first()
			
			if (api)
				return api.id
			else
				return nil
			end
			
		end
		
		def setup_apigateway_create_rest_api(api_name)
			
			puts 'Creating API with name ' + api_name
			api = @client.create_rest_api({name: api_name})
			
			return api.id
			
		end
		
		def setup_apigateway_create_resources(api_id)
			
			raise 'API ID not provided' if !api_id
			
			swagger_file = File.join(PWD, 'doc', 'swagger.json')
			cmd = "aws-api-import.cmd --update #{api_id} --region #{ENV['AWS_REGION']} #{swagger_file}"
			raise 'API gateway not created' if !system(cmd)
			
		end
		
		def create_stages(api_id, env)
		
			deployment_description = 'Deployment of service to ' + env
			deployment = @client.create_deployment({rest_api_id: api_id, stage_name: env, cache_cluster_enabled: false, description: deployment_description, variables: { "environment" => env}}).data
			puts deployment
			
		end
		
		def delete_stage(api_id, env)
			
			begin
				@client.delete_stage({rest_api_id: api_id, stage_name: env})
				puts 'Deleted API gateway stage ' + env
			rescue Aws::APIGateway::Errors::NotFoundException
				puts 'API Gateway stage ' + env + ' does not exist. Nothing to delete.'
			end
			
		end
		
	end
	
end