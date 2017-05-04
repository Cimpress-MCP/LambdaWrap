require 'aws-sdk'
require 'active_support/core_ext/hash'

module LambdaWrap
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
      full_table_name = @table_name + (@append_environment_on_deploy ? "-#{environment_options.name}" : '')

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
      full_table_name = @table_name + (@append_environment_on_deploy ? "-#{environment_options.name}" : '')
      delete_table(full_table_name)
    end

    def delete
      puts "Deleting all tables with prefix: #{@table_name}."
      table_names = retrieve_prefixed_tables(@table_name)
      table_names.each { |table_name| delete_table(table_name) }
      puts "Deleted #{table_names.length} tables."
    end

    private

    def retrieve_table_details(full_table_name)
      table_details = nil
      begin
        table_details = @dynamo_client.describe_table(table_name: full_table_name).table
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

        if details.table_status != 'ACTIVE'
          puts "Table: #{full_table_name} is not yet available. Status: #{details.table_status}. Retrying..."
        else
          updating_indexes = details.global_secondary_indexes.reject do |global_index|
            global_index.index_status == 'ACTIVE'
          end
          return true if updating_indexes.empty?
          puts 'Table is available, but the global indexes are not:'
          puts(updating_indexes.map { |global_index| "#{global_index.index_name}, #{global_index.index_status}" })
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
      global_secondary_index_updates = build_global_index_updates_array(table_details.global_secondary_indexes)
      unless global_secondary_index_updates.empty?
        update_global_indexes(full_table_name, global_secondary_index_updates)

        # Wait up to 4 hours.
        wait_until_table_is_available(full_table_name, 10, 1_440)
      end

      # Determine if there are new Global Secondary Indexes to be created.
      new_global_secondary_indexes = build_new_global_indexes_array(table_details.global_secondary_indexes)
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

    # Looks through the list current of Global Secondary Indexes and builds an array if the Provisioned Throughput
    # in the intended Indexes are higher than the current Indexes.
    def build_global_index_updates_array(current_global_indexes)
      indexes_to_update = []
      return indexes_to_update if current_global_indexes.empty?
      target_indexes
      current_global_indexes.each do |current_index|
        @global_secondary_indexes.each do |target_index|
          # Find the same named index
          next unless target_index[:index_name] == current_index
          # Skip unless higher Provisioned Throughput is specified
          break unless (target_index[:provisioned_throughput][:read_capacity_units] >
                        current_index.provisioned_throughput.read_capacity_units) ||
                       (target_index[:provisioned_throughput][:write_capacity_units] >
                        current_index.provisioned_throughput.write_capacity_units)
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
      puts 'Sleeping for 60 seconds...'
      sleep(60)

      # Wait for up to 2m.
      wait_until_table_is_available(full_table_name, 5, 24)
    end

    def delete_table(full_table_name)
      puts "Trying to delete Table: #{full_table_name}"
      table_details = get_table_details(full_table_name)
      if table_details.nil?
        puts 'Table did not exist. Nothing to delete.'
      else
        # Wait up to 30m
        wait_until_table_available(full_table_name, 5, 360) if table_details.table_status != 'ACTIVE'
        @dynamo_client.delete_table(table_name: full_table_name)
      end
    end

    def retrieve_prefixed_tables(prefix)
      all_table_names = []
      paginated_tables = retrieve_tables
      all_table_names.concat(paginated_tables)
      while paginated_tables.length == 100
        paginated_tables = retrieve_tables(paginated_tables.last)
        all_table_names.concat(paginated_tables)
      end
      # Filter on names with the prefix.
      all_table_names.select { |name| name =~ /#{Regexp.quote(prefix)}[a-zA-Z0-9_\-.]*/ }
    end

    def retrieve_paginated_tables(last_retrieved = nil)
      if last_retrieved.nil?
        @dynamo_client.list_tables.table_names
      else
        @dynamo_client.list_tables(exclusive_start_table_name: last_retrieved).table_names
      end
    end
  end
end
