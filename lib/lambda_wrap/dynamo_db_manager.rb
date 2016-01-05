require 'aws-sdk'
require_relative 'aws_setup'

module LambdaWrap
	
	class DynamoDbManager

		def initialize()
			AwsSetup.new.validate()
			# AWS dynamodb client
			@client = Aws::DynamoDB::Client.new()
		end
		
		def publish_database(table_name, attribute_definitions, key_schema, read_capacity, write_capacity)
			
			has_updates = false
			
			# figure out whether the table exists
			begin
				table_details = @client.describe_table(table_name: table_name).table
			rescue Aws::DynamoDB::Errors::ResourceNotFoundException
			end
			
			if (table_details)
				wait_until_table_available(table_name) if (table_details.table_status != 'ACTIVE')
				
				if (read_capacity > table_details.provisioned_throughput.read_capacity_units ||
					write_capacity > table_details.provisioned_throughput.write_capacity_units)
					puts "Updating new read/write capacity for table #{table_name}. 
						Read #{table_details.provisioned_throughput.read_capacity_units} ==> #{read_capacity}.
						Write #{table_details.provisioned_throughput.write_capacity_units} ==> #{write_capacity}."
					table = @client.update_table({
						table_name: table_name,
							provisioned_throughput: { read_capacity_units: read_capacity, write_capacity_units: write_capacity }
							})
					has_updates = true
				else
					puts "Table #{table_name} already exists and the desired read capacity of #{read_capacity} and write capacity of #{write_capacity} has at least been configured. Downgrading capacity units is not supported. No changes were applied."
				end
			else
				puts "Creating table #{table_name}."
				ad = attribute_definitions || [{ attribute_name: "Id", attribute_type: "S" }]
				ks = key_schema || [{ attribute_name: "Id", key_type: "HASH" }]
				table = @client.create_table({
					attribute_definitions: ad,
					table_name: table_name,
					key_schema: ks,
					provisioned_throughput: {read_capacity_units: read_capacity, write_capacity_units: write_capacity}
					})
				has_updates = true
			end
			
			if (has_updates)
				wait_until_table_available(table_name)
				puts "DynamoDB table #{table_name} is now fully available."
			end
		
		end
		
		def delete_database(table_name)
			
			begin
				table_details = @client.describe_table(table_name: table_name).table
				wait_until_table_available(table_name) if (table_details.table_status != 'ACTIVE')
				@client.delete_table({table_name: table_name})
			rescue Aws::DynamoDB::Errors::ResourceNotFoundException
				puts 'Table did not exist. Nothing to delete.'
			end
			
		end
		
		def wait_until_table_available(table_name)
		
			max_attempts = 24
			delay_between_attempts = 5
			
			# wait until the table has updated to being fully available
			# waiting for ~2min at most; an error will be thrown afterwards
			begin
				@client.wait_until(:table_exists, table_name: table_name) do |w|
					w.max_attempts = max_attempts
					w.delay = delay_between_attempts
					w.before_wait do |attempts, response|
						puts "Waiting until table becomes available. Attempt #{attempts}/#{max_attempts} with polling interval #{delay_between_attempts}."
					end
				end
			rescue Aws::Waiters::Errors::TooManyAttemptsError => e
				puts "Table #{table_name} did not become available after #{e.attempts} attempts. Try again later or inspect the AWS console."
			end
		
		end

	end

end