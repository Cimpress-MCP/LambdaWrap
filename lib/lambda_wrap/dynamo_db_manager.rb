require 'aws-sdk'

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
    # Updates the provisioned throughput read and write capacity of the requested table.
    # If the table does not exist an error message is displayed. If current read/write capacity
    # is equals to requested read/write capacity or the requested read/write capacity is 0 or less than 0
    # no table updation is performed.
    #
    # *Arguments*
    # [table_name]        The table name of the dynamoDB to be updated.
    # [read_capacity]     The read capacity the table should be updated with.
    # [write_capacity]    The write capacity the table should be updated with.
    def update_table_capacity(table_name, read_capacity, write_capacity)
      # Check if table exists.
      begin
        table_details = @client.describe_table(table_name: table_name).table
      rescue Aws::DynamoDB::Errors::ResourceNotFoundException
        raise "Update cannot be performed. Table #{table_name} does not exists."
      end

      if (read_capacity <= 0 || write_capacity <= 0)
        puts "Table: #{table_name} not updated. Read/Write capacity should be greater than or equal to 1."
      elsif (read_capacity == table_details.provisioned_throughput.read_capacity_units ||
            write_capacity == table_details.provisioned_throughput.write_capacity_units)
        puts "Table: #{table_name} not updated. Current and requested reads/writes are same.
        Current ReadCapacityUnits provisioned for the table: #{table_details.provisioned_throughput.read_capacity_units}.
        Requested ReadCapacityUnits: #{read_capacity}.
        Current WriteCapacityUnits provisioned for the table: #{table_details.provisioned_throughput.write_capacity_units}.
        Requested WriteCapacityUnits: #{write_capacity}. "
      else
        response = @client.update_table(
          table_name: table_name,
          provisioned_throughput: { read_capacity_units: read_capacity, write_capacity_units: write_capacity })

        raise "Read and writes capacities was not updated for table: #{table_name}." unless (response.table_description.provisioned_throughput.read_capacity_units!= read_capacity ||
        response.table_description.provisioned_throughput.write_capacity_units!= write_capacity)

        puts "Updated new read/write capacity for table #{table_name}.
        Read capacity updated to: #{read_capacity}.
        Write capacity updated to: #{write_capacity}."
      end
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
    # [local_secondary_indexes]     The local secondary indexes to be created.
    # [global_secondary_indexes]        The global secondary indexes to be created.
    def publish_database(
        table_name, attribute_definitions, key_schema, read_capacity, write_capacity, local_secondary_indexes = nil,
        global_secondary_indexes = nil
    )
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

        params = {
            table_name: table_name, key_schema: ks, attribute_definitions: ad,
            provisioned_throughput: {
                read_capacity_units: read_capacity, write_capacity_units: write_capacity
            }
        }

        params[:local_secondary_indexes] = local_secondary_indexes if local_secondary_indexes != nil
        params[:global_secondary_indexes] = global_secondary_indexes if global_secondary_indexes != nil

        @client.create_table(params)
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
