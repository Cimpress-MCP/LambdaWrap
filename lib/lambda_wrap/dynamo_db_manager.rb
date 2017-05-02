require 'aws-sdk'
require 'active_support/core_ext/hash'

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
      @client = Aws::DynamoDB::Client.new
    end

    def set_table_capacity(table_name, read_capacity, write_capacity)
      table_details = get_table_details(table_name)
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
    # [table_name]  The table name of the dynamoDB to be updated.
    # [read_capacity]  The read capacity the table should be updated with.
    # [write_capacity]  The write capacity the table should be updated with.
    def update_table_capacity(table_name, read_capacity, write_capacity)
      table_details = get_table_details(table_name)
      raise "Update cannot be performed. Table #{table_name} does not exists." if table_details.nil?

      wait_until_table_available(table_name) if table_details.table_status != 'ACTIVE'

      if read_capacity <= 0 || write_capacity <= 0
        puts "Table: #{table_name} not updated. Read/Write capacity should be greater than or equal to 1."
      elsif read_capacity == table_details.provisioned_throughput.read_capacity_units ||
            write_capacity == table_details.provisioned_throughput.write_capacity_units
        puts "Table: #{table_name} not updated. Current and requested reads/writes are same."
        puts 'Current ReadCapacityUnits provisioned for the table: ' \
                "#{table_details.provisioned_throughput.read_capacity_units}."
        puts "Requested ReadCapacityUnits: #{read_capacity}."
        puts 'Current WriteCapacityUnits provisioned for the table: ' \
          "#{table_details.provisioned_throughput.write_capacity_units}."
        puts "Requested WriteCapacityUnits: #{write_capacity}."
      else
        response = @client.update_table(
          table_name: table_name,
          provisioned_throughput: { read_capacity_units: read_capacity, write_capacity_units: write_capacity }
        )

        if response.table_description.table_status == 'UPDATING'
          puts "Updated new read/write capacity for table #{table_name}.
          Read capacity updated to: #{read_capacity}.
          Write capacity updated to: #{write_capacity}."
        else
          raise "Read and writes capacities was not updated for table: #{table_name}."
        end
      end
    end

    ##
    # Publishes the database and awaits until it is fully available. If the table already exists, it only adjusts the
    # read and write capacities upwards (it doesn't downgrade them to avoid a production environment being impacted with
    # a default setting of an automated script).
    #
    # *Arguments*
    # [table_name]  The table name of the dynamoDB to be created.
    # [attribute_definitions]  The dynamoDB attribute definitions to be used when the table is created.
    # [key_schema]  The dynamoDB key definitions to be used when the table is created.
    # [read_capacity]  The read capacity to configure for the dynamoDB table.
    # [write_capacity]  The write capacity to configure for the dynamoDB table.
    # [local_secondary_indexes]  The local secondary indexes to be created.
    # [global_secondary_indexes]  The global secondary indexes to be created.
    def publish_database(
        table_name, attribute_definitions, key_schema, read_capacity, write_capacity, local_secondary_indexes = nil,
        global_secondary_indexes = nil
    )
      has_updates = false

      table_details = get_table_details(table_name)

      if !table_details.nil?
        wait_until_table_available(table_name) if table_details.table_status != 'ACTIVE'

        if  read_capacity > table_details.provisioned_throughput.read_capacity_units ||
            write_capacity > table_details.provisioned_throughput.write_capacity_units
          set_table_capacity(table_name, read_capacity, write_capacity)
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

        params[:local_secondary_indexes] = local_secondary_indexes unless local_secondary_indexes.nil?
        params[:global_secondary_indexes] = global_secondary_indexes unless global_secondary_indexes.nil?

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
      table_details = get_table_details(table_name)
      if table_details.nil?
        puts 'Table did not exist. Nothing to delete.'
      else
        wait_until_table_available(table_name) if table_details.table_status != 'ACTIVE'
        @client.delete_table(table_name: table_name)
      end
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

    def get_table_details(table_name)
      table_details = nil
      begin
        table_details = @client.describe_table(table_name: table_name).table
      rescue Aws::DynamoDB::Errors::ResourceNotFoundException
        puts "Table #{table_name} does not exist."
      end
      table_details
    end

    private :wait_until_table_available, :get_table_details
  end

  ##
  # The DynamoTable class simplifies Creation, Updating, and Destroying Dynamo DB Tables.
  class DynamoTable < AwsService
    ##
    # Sets up the DynamoTable for the Dynamo DB Manager.
    def initialize(options)
      default_options = { append_environment_on_deploy: false, read_capacity: 1, write_capacity: 1,
                          local_secondary_indexes: nil, global_secondary_indexes: nil,
                          attribute_definitions: [{ attribute_name: 'Id', attribute_type: 'S' }],
                          key_schema: [{ attribute_name: 'Id', key_type: 'HASH' }] }

      options_with_defaults = options.reverse_merge(default_options)

      @table_name = options_with_defaults[:name]
      raise ArgumentException, ':table_name is required.' unless @table_name

      @attribute_definitions = options_with_defaults[:attribute_definitions]

      @key_schema = options_with_defaults[:key_schema]

      @read_capacity = options_with_defaults[:read_capacity]
      @write_capacity = options_with_defaults[:write_capacity]
      unless @read_capacity >= 1 && @write_capacity >= 1 && (@read_capacity.is_a? Integer) &&
             (@write_capacity.is_a? Integer)
        raise ArgumentExecption, 'Read and Write Capacity must be positive integers.'
      end

      @local_secondary_indexes = options_with_defaults[:local_secondary_indexes]

      @global_secondary_indexes = options_with_defaults[:global_secondary_indexes]

      @append_environment_on_deploy = options_with_defaults[:append_environment_on_deploy]
    end

    def deploy(environment_options)
      super
      full_table_name = @table_name + (@append_environment_on_deploy ? "-#{environment_options[:name]}" : '')

      table_details = retrieve_table_details(full_table_name)

      if !table_details.nil?
        wait_until_table_is_available(full_table_name) if table_details[:table_status] != 'ACTIVE'
        update_table(full_table_name, table_details)
      else
        create_table(full_table_name)
      end

      puts "Dynamo Table #{full_table_name} is now available."
    end

    def teardown(environment_options)
      super
      # full_table_name = @table_name + (@append_environment_on_deploy ? "-#{environment_options[:name]}" : '')
    end

    def delete; end

    private

    def retrieve_table_details(full_table_name)
      table_details = nil
      begin
        table_details = @dynamo_client.describe_table(table_name: full_table_name)[:table]
      rescue Aws::DynamoDB::Errors::ResourceNotFoundException
        puts "Table #{full_table_name} does not exist."
      end
      table_details
    end

    ##
    # Waits for the table to be available
    def wait_until_table_is_available(full_table_name, delay = 5, max_attempts = 25)
      puts "Waiting for Table #{full_table_name} to be available."
      puts "Waiting with a #{delay} second delay between attempts, for a maximum of #{attempts} attempts."
      max_time = Time.at(delay * attempts).utc.strftime('%H:%M:%S')
      puts "Max waiting time will be: #{max_time} (approximate)."
      # wait until the table has updated to being fully available
      # waiting for ~2min at most; an error will be thrown afterwards

      started_waiting_at = Time.now
      max_attempts.times do |attempt|
        puts "Attempt #{attempt}/#{max_attempts}, \
        #{Time.at(Time.now - started_waiting_at).utc.strftime('%H:%M:%S')}/#{max_time}"

        details = retrieve_table_details(full_table_name)

        if details[:table_status] != 'ACTIVE'
          puts "Table: #{full_table_name} is not yet available. Status: #{details[:table_status]}. Retrying..."
        else
          updating_indexes = details.global_secondary_indexes.reject do |global_index|
            global_index[:index_status] == 'ACTIVE'
          end
          return true if updating_indexes.empty?
          puts 'Table is available, but the global indexes are not:'
          puts(updating_indexes.map { |global_index| "#{global_index[:index_name]}, #{global_index[:index_status]}" })
        end
        sleep(delay)
      end

      raise Exception, "Table #{full_table_name} did not become available after #{max_attempts}. " \
        'Try again later or inspect the AWS console.'
    end

    ##
    # Updates the Dynamo Table. You can only perform one of the following update operations at once:
    # * Modify the provisioned throughput settings of the table.
    # * Enable or disable Streams on the table.
    # * Remove a global secondary index from the table.
    # * Create a new global secondary index on the table. Once the index begins backfilling,
    #     you can use UpdateTable to perform other operations.
    def update_table(full_table_name, table_details)
      # Determine if Provisioned Throughput needs to be updated.
      if  @read_capacity >= table_details.provisioned_throughput.read_capacity_units &&
          @write_capacity >= table_details.provisioned_throughput.write_capacity_units

        update_provisioned_throughput(
          full_table_name, table_details.provisioned_throughput.read_capacity_units,
          table_details.provisioned_throughput.write_capacity_units
        )

        # Wait up to 30 minutes.
        wait_until_table_is_available(full_table_name, 5, 360)
      end

      # Determine if there are any Global Secondary Indexes to be deleted.
      global_seconday_indexes_to_delete = build_global_index_deletes_array(table_details.global_secondary_indexes)
      unless global_seconday_indexes_to_delete.empty?
        # Loop through each index to delete, and send the update one at a time (restriction on the API).
        until global_secondary_indexes_to_delete.empty?
          delete_global_index(full_table_name, global_secondary_indexes_to_delete.pop)

          # Wait up to 2 hours.
          wait_until_table_is_available(full_table_name, 10, 720)
        end
      end

      # Determine if there are updates to the Provisioned Throughput of the Global Secondary Indexes
      global_secondary_index_updates = build_global_index_updates_array(table_details[:global_secondary_indexes])
      unless global_secondary_index_updates.empty?
        update_global_indexes(full_table_name, global_secondary_index_updates)

        # Wait up to 4 hours.
        wait_until_table_is_available(full_table_name, 10, 1_440)
      end

      # Determine if there are new Global Secondary Indexes to be created.
      new_global_secondary_indexes = build_new_global_indexes_array(table_details[:global_secondary_indexes])
      return if new_global_secondary_indexes.empty?

      create_global_indexes(full_table_name, new_global_secondary_indexes)

      # Wait up to 4 hours.
      wait_until_table_is_available(full_table_name, 10, 1_440)
    end

    def update_provisioned_throughput(full_table_name, old_read, old_write)
      puts "Updating Provisioned Throughtput for #{full_table_name}"
      puts "Setting Read Capacity Units From: #{old_read} To: #{@read_capacity}"
      puts "Setting Write Capacty Units From: #{old_write} To: #{@write_capacity}"
      @dynamo_client.update_table(
        table_name: full_table_name,
        provisioned_throughput: { read_capacity_units: @read_capacity, write_capacity_units: @write_capacity }
      )
    end

    def build_global_index_deletes_array(current_global_indexes)
      return [] if current_global_indexes.empty?
      current_index_names = current_global_indexes.map(&:index_name)
      target_index_names = @global_secondary_indexes.map(&:index_name)
      current_index_names - target_index_names
    end

    def delete_global_index(full_table_name, index_to_delete)
      puts "Deleting Global Secondary Index: #{index_to_delete} from Table: #{full_table_name}"
      @dynamo_client.update_table(
        table_name: full_table_name,
        global_secondary_index_updates: [{ delete: { index_name: index_to_delete } }]
      )
    end

    def build_global_index_updates_array(current_global_indexes)
      indexes_to_update = []
      return indexes_to_update if current_global_indexes.empty?
      target_indexes
      current_global_indexes.each do |current_index|
        @global_secondary_indexes.each do |target_index|
          next unless target_index[:index_name] == current_index &&
                      (target_index[:provisioned_throughput][:read_capacity_units] >
                        current_index[:provisioned_throughput][:read_capacity_units] ||
                        target_index[:provisioned_throughput][:write_capacity_units] >
                        current_index[:provisioned_throughput][:write_capacity_units])
          indexes_to_update << target_index
        end
      end
    end

    def update_global_indexes(full_table_name, global_secondary_index_updates)
      puts "Updating Global Indexes for Table: #{full_table_name}"
      puts(
        global_secondary_index_updates.map do |index|
          "#{index[:index_name]} - \
          Read: #{index[:provisioned_throughput][:read_capacity_units]}, \
          Write: #{index[:provisioned_throughput][:write_capacity_units]}"
        end
      )
      @dynamo_client.update_table(
        table_name: full_table_name,
        global_secondary_index_updates: global_secondary_index_updates.map { |index| { update: index } }
      )
    end

    def create_table(full_table_name)
      puts "Creating table #{full_table_name}..."
      @dynamo_client.create_table(
        table_name: full_table_name, attribute_definitions: @attribute_definitions,
        key_schema: @key_schema,
        provisioned_throughput: { read_capacity_units: @read_capacity,
                                  write_capacity_units: @write_capacity },
        local_secondary_indexes: @local_secondary_indexes,
        global_secondary_indexes: @global_secondary_indexes
      )
      # Wait 60 seconds because "DescribeTable uses an eventually consistent query"
      sleep(60)

      # Wait for up to 2m.
      wait_until_table_is_available(full_table_name, 5, 24)
    end

    def delete_database(full_table_name)
      puts "Trying to delete Table: #{full_Table_name}"
      table_details = get_table_details(full_table_name)
      if table_details.nil?
        puts 'Table did not exist. Nothing to delete.'
      else
        wait_until_table_available(full_table_name) if table_details.table_status != 'ACTIVE'
        @dynamo_client.delete_table(table_name: full_table_name)
      end
    end
  end
end
