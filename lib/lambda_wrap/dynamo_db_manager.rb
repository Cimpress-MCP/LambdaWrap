require 'aws-sdk'
require_relative 'aws_setup'

module LambdaWrap
  # The DynamoDBManager simplifies setting up and destroying a DynamoDB database.
  #
  # Note: In case an environment specific DynamoDB tablename such as +<baseTableName>-production+ should be used, then
  # it has to be injected directly to the methods since not all environments necessarily need separated databases.
  class DynamoDbManager
    ##
    # The constructor does some basic setup
    # * Validating basic AWS configuration
    # * Creating the underlying client to interact with the AWS SDK.
    def initialize
      AwsSetup.new.validate
      # AWS dynamodb client
      @client = Aws::DynamoDB::Client.new
    end

    def set_table_capacity(table_name, read_capacity, write_capacity)
      puts "Updating new read/write capacity for table #{table_name}.
       Read #{table_details.provisioned_throughput.read_capacity_units} ==> #{read_capacity}.
       Write #{table_details.provisioned_throughput.write_capacity_units} ==> #{write_capacity}."
      @client.update_table(
        table_name: table_name,
        provisioned_throughput: { read_capacity_units: read_capacity, write_capacity_units: write_capacity }
      )
    end

    ##
    # Publishes the database and awaits until it is fully available. If the table already exists,
    # it only adjusts the read and write
    # capacities upwards (it doesn't downgrade them to avoid a production environment being impacted with
    # a default setting of an automated script).
    #
    # *Arguments*
    # [table_name]        The table name of the dynamoDB to be created.
    # [attribute_definitions]  The dynamoDB attribute definitions to be used when the table is created.
    # [key_schema]        The dynamoDB key definitions to be used when the table is created.
    # [read_capacity]      The read capacity to configure for the dynamoDB table.
    # [write_capacity]      The write capacity to configure for the dynamoDB table.
    def publish_database(table_name, attribute_definitions, key_schema, read_capacity, write_capacity)
      has_updates = false

      # figure out whether the table exists
      begin
        table_details = @client.describe_table(table_name: table_name).table
      rescue Aws::DynamoDB::Errors::ResourceNotFoundException
        # skip this exception because we are using it for control flow.
        table_details = nil
      end

      if table_details
        wait_until_table_available(table_name) if table_details.table_status != 'ACTIVE'

        if read_capacity > table_details.provisioned_throughput.read_capacity_units ||
           write_capacity > table_details.provisioned_throughput.write_capacity_units

          set_table_capacity read_capacity, write_capacity
          has_updates = true
        else
          puts "Table #{table_name} already exists and the desired read capacity of #{read_capacity} and " \
          "write capacity of #{write_capacity} has at least been configured. Downgrading capacity units is not " \
          'supported. No changes were applied.'
        end
      else
        puts "Creating table #{table_name}."
        ad = attribute_definitions || [{ attribute_name: 'Id', attribute_type: 'S' }]
        ks = key_schema || [{ attribute_name: 'Id', key_type: 'HASH' }]
        @client.create_table(table_name: table_name, key_schema: ks, attribute_definitions: ad,
                             provisioned_throughput:
                               { read_capacity_units: read_capacity, write_capacity_units: write_capacity })
        has_updates = true
      end

      if has_updates
        wait_until_table_available(table_name)
        puts "DynamoDB table #{table_name} is now fully available."
      end
    end

    ##
    # Deletes a DynamoDB table. It does not wait until the table has been deleted.
    #
    # *Arguments*
    # [table_name]  The dynamoDB table name to delete.
    def delete_database(table_name)
      table_details = @client.describe_table(table_name: table_name).table
      wait_until_table_available(table_name) if table_details.table_status != 'ACTIVE'
      @client.delete_table(table_name: table_name)
    rescue Aws::DynamoDB::Errors::ResourceNotFoundException
      puts 'Table did not exist. Nothing to delete.'
    end

    ##
    # Awaits a given status of a table.
    #
    # *Arguments*
    # [table_name]  The dynamoDB table name to watch until it reaches an active status.
    def wait_until_table_available(table_name)
      max_attempts = 24
      delay_between_attempts = 5

      # wait until the table has updated to being fully available
      # waiting for ~2min at most; an error will be thrown afterwards
      begin
        @client.wait_until(:table_exists, table_name: table_name) do |w|
          w.max_attempts = max_attempts
          w.delay = delay_between_attempts
          w.before_wait do |attempts, _|
            puts "Waiting until table becomes available. Attempt #{attempts}/#{max_attempts} " \
                 "with polling interval #{delay_between_attempts}."
          end
        end
      rescue Aws::Waiters::Errors::TooManyAttemptsError => e
        puts "Table #{table_name} did not become available after #{e.attempts} attempts. " \
        'Try again later or inspect the AWS console.'
      end
    end

    private :wait_until_table_available
  end
end
