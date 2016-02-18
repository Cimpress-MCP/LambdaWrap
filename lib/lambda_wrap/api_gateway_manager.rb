require 'aws-sdk'
require_relative 'aws_setup'

module LambdaWrap
	
	##
	# The ApiGatewayManager simplifies downloading the aws-apigateway-importer binary,
	# importing a {swagger configuration}[http://swagger.io], and managing API Gateway stages.
	#
	# Note: The concept of an environment of the LambdaWrap gem matches a stage in AWS ApiGateway terms.
	class ApiGatewayManager
		
		##
		# The constructor does some basic setup
		# * Validating basic AWS configuration
		# * Creating the underlying client to interact with the AWS SDK.
		# * Defining the temporary path of the api-gateway-importer jar file
		def initialize()
			AwsSetup.new.validate()
			# AWS api gateway client
			@client = Aws::APIGateway::Client.new()
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
		# [s3_bucket]		An S3 bucket from where the aws-apigateway-importer binary can be downloaded.
		# [s3_key]			The path (key) to the aws-apigateay-importer binary on the s3 bucket.
		def download_apigateway_importer(s3_bucket, s3_key)
			
			s3 = Aws::S3::Client.new
			
			# current version
			current_s3_version = File.open(@versionpath, 'rb').read if File.exists?(@versionpath)
			
			# online s3 version
			desired_s3_version = s3.head_object(bucket:s3_bucket, key:s3_key).version_id
			
			# compare local with remote version
			if current_s3_version != desired_s3_version || !File.exists?(@jarpath)
				puts "Downloading aws-apigateway-importer jar with S3 version #{desired_s3_version}"
				obj = s3.get_object(response_target:@jarpath, bucket:s3_bucket, key:s3_key)
				File.write(@versionpath, desired_s3_version)
			end
			
		end
		
		##
		# Sets up the API gateway by searching whether the API Gateway already exists
		# and updates it with the latest information from the swagger file.
		# 
		# *Arguments*
		# [api_name]		The name of the API to which the swagger file should be applied to.
		# [env]				The environment where it should be published (which is matching an API gateway stage)
		# [swagger_file]	A handle to a swagger file that should be used by aws-apigateway-importer
		def setup_apigateway(api_name, env, swagger_file)
			
			# ensure API is created
			api_id = get_existing_rest_api(api_name)
			api_id = setup_apigateway_create_rest_api(api_name) if !api_id
			
			# create resources
			setup_apigateway_create_resources(api_id, swagger_file)
			
			# create stages
			create_stages(api_id, env)
			
			# return URI of created stage
			return "https://#{api_id}.execute-api.#{ENV['AWS_REGION']}.amazonaws.com/#{env}/"
			
		end
		
		##
		# Shuts down an environment from the API Gateway. This basically deletes the stage
		# from the API Gateway, but does not delete the API Gateway itself.
		#
		# *Argument*
		# [api_name]		The name of the API where the environment should be shut down.
		# [env]				The environment (matching an API Gateway stage) to shutdown.
		def shutdown_apigateway(api_name, env)
		
			api_id = get_existing_rest_api(api_name)
			delete_stage(api_id, env)
			
		end
		
		##
		# Gets the ID of an existing API Gateway api, or nil if it doesn't exist
		# 
		# *Arguments*
		# [api_name]		The name of the API to be checked for existance
		def get_existing_rest_api(api_name)
			
			apis = @client.get_rest_apis({limit: 500}).data
			api = apis.items.select{ |api| api.name == api_name}.first()
			
			if (api)
				return api.id
			else
				return nil
			end
			
		end
		
		##
		# Creates the API with a given name and returns the id
		# 
		# *Arguments*
		# [api_name]		The name of the API to be created
		def setup_apigateway_create_rest_api(api_name)
			
			puts 'Creating API with name ' + api_name
			api = @client.create_rest_api({name: api_name})
			
			return api.id
			
		end
		
		##
		# Invokes the aws-apigateway-importer jar with the required parameter
		# 
		# *Arguments*
		# [api_id]			The AWS ApiGateway id where the swagger file should be applied to.
		# [swagger_file]	The handle to a swagger definition file that should be imported into API Gateway
		def setup_apigateway_create_resources(api_id, swagger_file)
			
			raise 'API ID not provided' if !api_id
			
			cmd = "java -jar #{@jarpath} --update #{api_id} --region #{ENV['AWS_REGION']} #{swagger_file}"
			raise 'API gateway not created' if !system(cmd)
			
		end
		
		##
		# Creates a stage of the currently set resources
		# 
		# *Arguments*
		# [api_id]			The AWS ApiGateway id where the stage should be created at.
		# [env]				The environment (which matches the stage in API Gateway) to create.
		def create_stages(api_id, env)
		
			deployment_description = 'Deployment of service to ' + env
			deployment = @client.create_deployment({rest_api_id: api_id, stage_name: env, cache_cluster_enabled: false, description: deployment_description, variables: { "environment" => env}}).data
			puts deployment
			
		end
		
		##
		# Deletes a stage of the API Gateway
		# 
		# *Arguments*
		# [api_id]			The AWS ApiGateway id from which the stage should be deleted from.
		# [env]				The environment (which matches the stage in API Gateway) to delete.
		def delete_stage(api_id, env)
			
			begin
				@client.delete_stage({rest_api_id: api_id, stage_name: env})
				puts 'Deleted API gateway stage ' + env
			rescue Aws::APIGateway::Errors::NotFoundException
				puts 'API Gateway stage ' + env + ' does not exist. Nothing to delete.'
			end
			
		end
		
		private :get_existing_rest_api, :setup_apigateway_create_rest_api, :setup_apigateway_create_resources, :create_stages, :delete_stage
		
	end
	
end