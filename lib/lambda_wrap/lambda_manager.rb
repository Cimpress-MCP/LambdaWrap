require 'aws-sdk'
require_relative 'aws_setup'

module LambdaWrap
	
	class LambdaManager
		
		def initialize()
			AwsSetup.new.validate()
			# AWS lambda client
			@client = Aws::Lambda::Client.new()
		end
		
		def package(directory, zipfile, input_filenames, node_modules)
			
			FileUtils::mkdir_p directory
			FileUtils::mkdir_p File.join(directory, 'node_modules')

			input_filenames.each do |filename|
				FileUtils::copy_file(File.join(filename), File.join(directory, File.basename(filename)))
			end

			node_modules.each do |dir|
				FileUtils::cp_r(File.join('node_modules', dir), File.join(directory, 'node_modules'))
			end

			ZipFileGenerator.new(directory, zipfile).write
			
		end
		
		def publish_lambda_to_s3(local_lambda_file, bucket, key)
			
			# get s3 object
			s3 = Aws::S3::Resource.new()
			obj = s3.bucket(bucket).object(key)
			
			# upload
			version_id = nil
			File.open(local_lambda_file, 'rb') do |file|
				version_id = obj.put({body: file}).version_id
			end
			raise 'Upload to S3 failed' if !version_id
			
			puts 'Uploaded object to S3 with version ' + version_id
			return version_id
			
		end
		
		def deploy_lambda(version_id, function_name, handler)
	
			# create or update function
			
			begin
				func = @client.get_function({function_name: function_name})
				func_config = @client.update_function_code({function_name: function_name, s3_bucket: S3_BUCKET, s3_key: S3_KEY, s3_object_version: version_id, publish: true}).data
				puts func_config
				func_version = func_config.version
				raise 'Error while publishing existing lambda function ' + function_name if !func_config.version
			rescue Aws::Lambda::Errors::ResourceNotFoundException
				func_config = @client.create_function({function_name: function_name, runtime: 'nodejs', role: LAMBDA_ROLE_ARN, handler: handler, code: { s3_bucket: S3_BUCKET, s3_key: S3_KEY }, timeout: 5, memory_size: 128, publish: true, description: 'created by an automated script'}).data
				puts func_config
				func_version = func_config.version
				raise 'Error while publishing new lambda function ' + function_name if !func_config.version
			end
			
			add_api_gateway_permissions(function_name, nil)
			
			return func_version
			
		end
		
		def create_alias(function_name, func_version, alias_name)
			
			# create or update alias
			func_alias = @client.list_aliases({function_name: function_name}).aliases.select{ |a| a.name == alias_name }.first()
			if (!func_alias)
				a = @client.create_alias({function_name: function_name, name: alias_name, function_version: func_version, description: 'created by an automated script'}).data
				puts a
			else
				a = @client.update_alias({function_name: function_name, name: alias_name, function_version: func_version, description: 'updated by an automated script'}).data
				puts a
			end
			
			add_api_gateway_permissions(function_name, alias_name)
			
		end
		
		def remove_alias(function_name, alias_name)
			
			@client.delete_alias({function_name: function_name, name: alias_name})
			
		end
		
		def add_api_gateway_permissions(function_name, env)
			# permissions to execute lambda
			suffix = (':' + env if env) || '' 
			func = @client.get_function({function_name: function_name + suffix}).data.configuration
			statement_id = func.function_name + (('-' + env if env) || '') 
			policy_exists = false
			begin
				existing_policies = @client.get_policy({function_name: func.function_arn}).data
				existing_policy = JSON.parse(existing_policies.policy)
				policy_exists = existing_policy['Statement'].select{ |s| s['Sid'] == statement_id}.any? 
			rescue Aws::Lambda::Errors::ResourceNotFoundException
			end
			
			if !policy_exists
				perm_add = @client.add_permission({function_name: func.function_arn, statement_id: statement_id, action: 'lambda:*', principal: 'apigateway.amazonaws.com'})
				puts perm_add.data
			end
		end
		
	end

end