require './test/helper.rb'

class TestDynamoTable < Minitest::Test
  describe LambdaWrap::DynamoTable do
    let(:new_table_valid_options) do
      {
        table_name: 'Issues', attribute_definitions:
          [
            { attribute_name: 'IssueId', attribute_type: 'S' },
            { attribute_name: 'Title', attribute_type: 'S' },
            { attribute_name: 'CreateDate', attribute_type: 'S' },
            { attribute_name: 'DueDate', attribute_type: 'S' }
          ],
        key_schema: [{ attribute_name: 'IssueId', key_type: 'HASH' },
                     { attribute_name: 'Title', key_type: 'RANGE' }],
        read_capacity_units: 8, write_capacity_units: 4,
        global_secondary_indexes:
          [
            {
              index_name: 'CreateDateIndex',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'CreateDate', key_type: 'HASH' },
                           { attribute_name: 'IssueId', key_type: 'RANGE' }],
              projection: {
                projection_type: 'INCLUDE',
                non_key_attributes: %w[Description Status]
              }
            },
            {
              index_name: 'TitleIndex',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'Title', key_type: 'HASH' },
                           { attribute_name: 'IssueId', key_type: 'RANGE' }],
              projection: {
                projection_type: 'KEYS_ONLY'
              }
            },
            {
              index_name: 'DueDateIndex',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'DueDate', key_type: 'HASH' }],
              projection: {
                projection_type: 'ALL'
              }
            }
          ],
        local_secondary_indexes:
          [
            { index_name: 'LocalIndex', key_schema: [{ attribute_name: 'Title', key_type: 'HASH' }],
              projection: { projection_type: 'ALL' } }
          ],
        append_environment_on_deploy: true
      }
    end

    let(:table_valid) do
      LambdaWrap::DynamoTable.new(new_table_valid_options)
    end

    let(:describe_table_response_valid1) do
      {
        table: {
          attribute_definitions:
            [
              { attribute_name: 'IssueId', attribute_type: 'S' },
              { attribute_name: 'Title', attribute_type: 'S' },
              { attribute_name: 'CreateDate', attribute_type: 'S' },
              { attribute_name: 'DueDate', attribute_type: 'S' }
            ],
          table_name: 'Issues-unittesting',
          key_schema: [{ attribute_name: 'IssueId', key_type: 'HASH' },
                       { attribute_name: 'Title', key_type: 'RANGE' }],
          table_status: 'ACTIVE',
          provisioned_throughput: { read_capacity_units: 4,
                                    write_capacity_units: 2 },
          table_arn: 'table_arn',
          local_secondary_indexes: [{
            index_name: 'LocalIndex', key_schema: [{ attribute_name: 'Title', key_type: 'HASH' }],
            projection: { projection_type: 'ALL' }
          }],
          global_secondary_indexes: [
            {
              index_name: 'CreateDateIndex',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'CreateDate', key_type: 'HASH' },
                           { attribute_name: 'IssueId', key_type: 'RANGE' }],
              projection: {
                projection_type: 'INCLUDE',
                non_key_attributes: %w[Description Status]
              },
              backfilling: false,
              index_status: 'ACTIVE'
            },
            {
              index_name: 'TitleIndex',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'Title', key_type: 'HASH' },
                           { attribute_name: 'IssueId', key_type: 'RANGE' }],
              projection: {
                projection_type: 'KEYS_ONLY'
              },
              backfilling: false,
              index_status: 'ACTIVE'
            },
            {
              index_name: 'DueDateIndex',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'DueDate', key_type: 'HASH' }],
              projection: {
                projection_type: 'ALL'
              },
              backfilling: false,
              index_status: 'ACTIVE'
            }
          ]
        }
      }
    end

    let(:describe_table_response_valid2) do
      {
        table: {
          attribute_definitions:
            [
              { attribute_name: 'IssueId', attribute_type: 'S' },
              { attribute_name: 'Title', attribute_type: 'S' },
              { attribute_name: 'CreateDate', attribute_type: 'S' },
              { attribute_name: 'DueDate', attribute_type: 'S' }
            ],
          table_name: 'Issues-unittesting',
          key_schema: [{ attribute_name: 'IssueId', key_type: 'HASH' },
                       { attribute_name: 'Title', key_type: 'RANGE' }],
          table_status: 'ACTIVE',
          provisioned_throughput: { read_capacity_units: 800,
                                    write_capacity_units: 40 },
          table_arn: 'table_arn',
          local_secondary_indexes: [{
            index_name: 'LocalIndex', key_schema: [{ attribute_name: 'Title', key_type: 'HASH' }],
            projection: { projection_type: 'ALL' }
          }],
          global_secondary_indexes: [
            {
              index_name: 'CreateDateIndex',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'CreateDate', key_type: 'HASH' },
                           { attribute_name: 'IssueId', key_type: 'RANGE' }],
              projection: {
                projection_type: 'INCLUDE',
                non_key_attributes: %w[Description Status]
              },
              backfilling: false,
              index_status: 'ACTIVE'
            },
            {
              index_name: 'TitleIndex',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'Title', key_type: 'HASH' },
                           { attribute_name: 'IssueId', key_type: 'RANGE' }],
              projection: {
                projection_type: 'KEYS_ONLY'
              },
              backfilling: false,
              index_status: 'ACTIVE'
            },
            {
              index_name: 'DueDateIndex',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'DueDate', key_type: 'HASH' }],
              projection: {
                projection_type: 'ALL'
              },
              backfilling: false,
              index_status: 'ACTIVE'
            }
          ]
        }
      }
    end

    let(:describe_table_response_valid3) do
      {
        table: {
          attribute_definitions:
            [
              { attribute_name: 'IssueId', attribute_type: 'S' },
              { attribute_name: 'Title', attribute_type: 'S' },
              { attribute_name: 'CreateDate', attribute_type: 'S' },
              { attribute_name: 'DueDate', attribute_type: 'S' }
            ],
          table_name: 'Issues-unittesting',
          key_schema: [{ attribute_name: 'IssueId', key_type: 'HASH' },
                       { attribute_name: 'Title', key_type: 'RANGE' }],
          table_status: 'ACTIVE',
          provisioned_throughput: { read_capacity_units: 800,
                                    write_capacity_units: 40 },
          table_arn: 'table_arn',
          local_secondary_indexes: [{
            index_name: 'LocalIndex', key_schema: [{ attribute_name: 'Title', key_type: 'HASH' }],
            projection: { projection_type: 'ALL' }
          }],
          global_secondary_indexes: [
            {
              index_name: 'CreateDateIndex',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'CreateDate', key_type: 'HASH' },
                           { attribute_name: 'IssueId', key_type: 'RANGE' }],
              projection: {
                projection_type: 'INCLUDE',
                non_key_attributes: %w[Description Status]
              },
              backfilling: false,
              index_status: 'ACTIVE'
            },
            {
              index_name: 'TitleIndex',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'Title', key_type: 'HASH' },
                           { attribute_name: 'IssueId', key_type: 'RANGE' }],
              projection: {
                projection_type: 'KEYS_ONLY'
              },
              backfilling: false,
              index_status: 'ACTIVE'
            }
          ]
        }
      }
    end

    let(:describe_table_response_valid4) do
      {
        table: {
          attribute_definitions:
            [
              { attribute_name: 'IssueId', attribute_type: 'S' },
              { attribute_name: 'Title', attribute_type: 'S' },
              { attribute_name: 'CreateDate', attribute_type: 'S' },
              { attribute_name: 'DueDate', attribute_type: 'S' }
            ],
          table_name: 'Issues-unittesting',
          key_schema: [{ attribute_name: 'IssueId', key_type: 'HASH' },
                       { attribute_name: 'Title', key_type: 'RANGE' }],
          table_status: 'ACTIVE',
          provisioned_throughput: { read_capacity_units: 800,
                                    write_capacity_units: 40 },
          table_arn: 'table_arn',
          local_secondary_indexes: [{
            index_name: 'LocalIndex', key_schema: [{ attribute_name: 'Title', key_type: 'HASH' }],
            projection: { projection_type: 'ALL' }
          }],
          global_secondary_indexes: [
            {
              index_name: 'CreateDateIndex',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'CreateDate', key_type: 'HASH' },
                           { attribute_name: 'IssueId', key_type: 'RANGE' }],
              projection: {
                projection_type: 'INCLUDE',
                non_key_attributes: %w[Description Status]
              },
              backfilling: false,
              index_status: 'ACTIVE'
            },
            {
              index_name: 'TitleIndex',
              provisioned_throughput: { read_capacity_units: 16, write_capacity_units: 4 },
              key_schema: [{ attribute_name: 'Title', key_type: 'HASH' },
                           { attribute_name: 'IssueId', key_type: 'RANGE' }],
              projection: {
                projection_type: 'KEYS_ONLY'
              },
              backfilling: false,
              index_status: 'ACTIVE'
            }
          ]
        }
      }
    end

    let(:describe_table_response_valid5) do
      {
        table: {
          attribute_definitions:
            [
              { attribute_name: 'IssueId', attribute_type: 'S' },
              { attribute_name: 'Title', attribute_type: 'S' },
              { attribute_name: 'CreateDate', attribute_type: 'S' },
              { attribute_name: 'DueDate', attribute_type: 'S' }
            ],
          table_name: 'Issues-unittesting',
          key_schema: [{ attribute_name: 'IssueId', key_type: 'HASH' },
                       { attribute_name: 'Title', key_type: 'RANGE' }],
          table_status: 'ACTIVE',
          provisioned_throughput: { read_capacity_units: 800,
                                    write_capacity_units: 40 },
          table_arn: 'table_arn',
          local_secondary_indexes: [{
            index_name: 'LocalIndex', key_schema: [{ attribute_name: 'Title', key_type: 'HASH' }],
            projection: { projection_type: 'ALL' }
          }],
          global_secondary_indexes: [
            {
              index_name: 'CreateDateIndex',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'CreateDate', key_type: 'HASH' },
                           { attribute_name: 'IssueId', key_type: 'RANGE' }],
              projection: {
                projection_type: 'INCLUDE',
                non_key_attributes: %w[Description Status]
              },
              backfilling: false,
              index_status: 'ACTIVE'
            },
            {
              index_name: 'TitleIndex',
              provisioned_throughput: { read_capacity_units: 16, write_capacity_units: 4 },
              key_schema: [{ attribute_name: 'Title', key_type: 'HASH' },
                           { attribute_name: 'IssueId', key_type: 'RANGE' }],
              projection: {
                projection_type: 'KEYS_ONLY'
              },
              backfilling: false,
              index_status: 'ACTIVE'
            },
            { # Index to be added
              index_name: 'NewIndex',
              provisioned_throughput: { read_capacity_units: 40, write_capacity_units: 4 },
              key_schema: [{ attribute_name: 'CreateDate', key_type: 'HASH' }],
              projection: {
                projection_type: 'ALL'
              },
              backfilling: true,
              index_status: 'ACTIVE'
            }
          ]
        }
      }
    end

    let(:describe_table_response_table_updating1) do
      {
        table: {
          attribute_definitions:
            [
              { attribute_name: 'IssueId', attribute_type: 'S' },
              { attribute_name: 'Title', attribute_type: 'S' },
              { attribute_name: 'CreateDate', attribute_type: 'S' },
              { attribute_name: 'DueDate', attribute_type: 'S' }
            ],
          table_name: 'Issues-unittesting',
          key_schema: [{ attribute_name: 'IssueId', key_type: 'HASH' },
                       { attribute_name: 'Title', key_type: 'RANGE' }],
          table_status: 'UPDATING',
          provisioned_throughput: { read_capacity_units: 4,
                                    write_capacity_units: 2 },
          table_arn: 'table_arn',
          local_secondary_indexes: [{
            index_name: 'LocalIndex', key_schema: [{ attribute_name: 'Title', key_type: 'HASH' }],
            projection: { projection_type: 'ALL' }
          }],
          global_secondary_indexes: [
            {
              index_name: 'CreateDateIndex',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'CreateDate', key_type: 'HASH' },
                           { attribute_name: 'IssueId', key_type: 'RANGE' }],
              projection: {
                projection_type: 'INCLUDE',
                non_key_attributes: %w[Description Status]
              },
              backfilling: false,
              index_status: 'ACTIVE'
            },
            {
              index_name: 'TitleIndex',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'Title', key_type: 'HASH' },
                           { attribute_name: 'IssueId', key_type: 'RANGE' }],
              projection: {
                projection_type: 'KEYS_ONLY'
              },
              backfilling: false,
              index_status: 'ACTIVE'
            },
            {
              index_name: 'DueDateIndex',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'DueDate', key_type: 'HASH' }],
              projection: {
                projection_type: 'ALL'
              },
              backfilling: false,
              index_status: 'ACTIVE'
            }
          ]
        }
      }
    end

    let(:describe_table_response_table_updating2) do
      {
        table: {
          attribute_definitions:
            [
              { attribute_name: 'IssueId', attribute_type: 'S' },
              { attribute_name: 'Title', attribute_type: 'S' },
              { attribute_name: 'CreateDate', attribute_type: 'S' },
              { attribute_name: 'DueDate', attribute_type: 'S' }
            ],
          table_name: 'Issues-unittesting',
          key_schema: [{ attribute_name: 'IssueId', key_type: 'HASH' },
                       { attribute_name: 'Title', key_type: 'RANGE' }],
          table_status: 'UPDATING',
          provisioned_throughput: { read_capacity_units: 800,
                                    write_capacity_units: 40 },
          table_arn: 'table_arn',
          local_secondary_indexes: [{
            index_name: 'LocalIndex', key_schema: [{ attribute_name: 'Title', key_type: 'HASH' }],
            projection: { projection_type: 'ALL' }
          }],
          global_secondary_indexes: [
            {
              index_name: 'CreateDateIndex',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'CreateDate', key_type: 'HASH' },
                           { attribute_name: 'IssueId', key_type: 'RANGE' }],
              projection: {
                projection_type: 'INCLUDE',
                non_key_attributes: %w[Description Status]
              },
              backfilling: false,
              index_status: 'ACTIVE'
            },
            {
              index_name: 'TitleIndex',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'Title', key_type: 'HASH' },
                           { attribute_name: 'IssueId', key_type: 'RANGE' }],
              projection: {
                projection_type: 'KEYS_ONLY'
              },
              backfilling: false,
              index_status: 'ACTIVE'
            },
            {
              index_name: 'DueDateIndex',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'DueDate', key_type: 'HASH' }],
              projection: {
                projection_type: 'ALL'
              },
              backfilling: false,
              index_status: 'ACTIVE'
            }
          ]
        }
      }
    end

    let(:describe_table_response_table_updating3) do
      {
        table: {
          attribute_definitions:
            [
              { attribute_name: 'IssueId', attribute_type: 'S' },
              { attribute_name: 'Title', attribute_type: 'S' },
              { attribute_name: 'CreateDate', attribute_type: 'S' },
              { attribute_name: 'DueDate', attribute_type: 'S' }
            ],
          table_name: 'Issues-unittesting',
          key_schema: [{ attribute_name: 'IssueId', key_type: 'HASH' },
                       { attribute_name: 'Title', key_type: 'RANGE' }],
          table_status: 'ACTIVE',
          provisioned_throughput: { read_capacity_units: 800,
                                    write_capacity_units: 40 },
          table_arn: 'table_arn',
          local_secondary_indexes: [{
            index_name: 'LocalIndex', key_schema: [{ attribute_name: 'Title', key_type: 'HASH' }],
            projection: { projection_type: 'ALL' }
          }],
          global_secondary_indexes: [
            {
              index_name: 'CreateDateIndex',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'CreateDate', key_type: 'HASH' },
                           { attribute_name: 'IssueId', key_type: 'RANGE' }],
              projection: {
                projection_type: 'INCLUDE',
                non_key_attributes: %w[Description Status]
              },
              backfilling: false,
              index_status: 'ACTIVE'
            },
            {
              index_name: 'TitleIndex',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'Title', key_type: 'HASH' },
                           { attribute_name: 'IssueId', key_type: 'RANGE' }],
              projection: {
                projection_type: 'KEYS_ONLY'
              },
              backfilling: false,
              index_status: 'ACTIVE'
            },
            {
              index_name: 'DueDateIndex',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'DueDate', key_type: 'HASH' }],
              projection: {
                projection_type: 'ALL'
              },
              backfilling: false,
              index_status: 'DELETING'
            }
          ]
        }
      }
    end

    let(:describe_table_response_table_updating4) do
      {
        table: {
          attribute_definitions:
            [
              { attribute_name: 'IssueId', attribute_type: 'S' },
              { attribute_name: 'Title', attribute_type: 'S' },
              { attribute_name: 'CreateDate', attribute_type: 'S' },
              { attribute_name: 'DueDate', attribute_type: 'S' }
            ],
          table_name: 'Issues-unittesting',
          key_schema: [{ attribute_name: 'IssueId', key_type: 'HASH' },
                       { attribute_name: 'Title', key_type: 'RANGE' }],
          table_status: 'ACTIVE',
          provisioned_throughput: { read_capacity_units: 800,
                                    write_capacity_units: 40 },
          table_arn: 'table_arn',
          local_secondary_indexes: [{
            index_name: 'LocalIndex', key_schema: [{ attribute_name: 'Title', key_type: 'HASH' }],
            projection: { projection_type: 'ALL' }
          }],
          global_secondary_indexes: [
            {
              index_name: 'CreateDateIndex',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'CreateDate', key_type: 'HASH' },
                           { attribute_name: 'IssueId', key_type: 'RANGE' }],
              projection: {
                projection_type: 'INCLUDE',
                non_key_attributes: %w[Description Status]
              },
              backfilling: false,
              index_status: 'ACTIVE'
            },
            {
              index_name: 'TitleIndex',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'Title', key_type: 'HASH' },
                           { attribute_name: 'IssueId', key_type: 'RANGE' }],
              projection: {
                projection_type: 'KEYS_ONLY'
              },
              backfilling: false,
              index_status: 'UPDATING'
            }
          ]
        }
      }
    end

    let(:describe_table_response_table_updating5) do
      {
        table: {
          attribute_definitions:
            [
              { attribute_name: 'IssueId', attribute_type: 'S' },
              { attribute_name: 'Title', attribute_type: 'S' },
              { attribute_name: 'CreateDate', attribute_type: 'S' },
              { attribute_name: 'DueDate', attribute_type: 'S' }
            ],
          table_name: 'Issues-unittesting',
          key_schema: [{ attribute_name: 'IssueId', key_type: 'HASH' },
                       { attribute_name: 'Title', key_type: 'RANGE' }],
          table_status: 'ACTIVE',
          provisioned_throughput: { read_capacity_units: 800,
                                    write_capacity_units: 40 },
          table_arn: 'table_arn',
          local_secondary_indexes: [{
            index_name: 'LocalIndex', key_schema: [{ attribute_name: 'Title', key_type: 'HASH' }],
            projection: { projection_type: 'ALL' }
          }],
          global_secondary_indexes: [
            {
              index_name: 'CreateDateIndex',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'CreateDate', key_type: 'HASH' },
                           { attribute_name: 'IssueId', key_type: 'RANGE' }],
              projection: {
                projection_type: 'INCLUDE',
                non_key_attributes: %w[Description Status]
              },
              backfilling: false,
              index_status: 'ACTIVE'
            },
            {
              index_name: 'TitleIndex',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'Title', key_type: 'HASH' },
                           { attribute_name: 'IssueId', key_type: 'RANGE' }],
              projection: {
                projection_type: 'KEYS_ONLY'
              },
              backfilling: false,
              index_status: 'ACTIVE'
            },
            { # Index to be added
              index_name: 'NewIndex',
              provisioned_throughput: { read_capacity_units: 40, write_capacity_units: 4 },
              key_schema: [{ attribute_name: 'CreateDate', key_type: 'HASH' }],
              projection: {
                projection_type: 'ALL'
              },
              backfilling: true,
              index_status: 'CREATING'
            }
          ]
        }
      }
    end

    let(:environment_valid) do
      LambdaWrap::Environment.new('unittesting', { foo: 'bar' }, 'valid description')
    end

    let(:create_table_response_valid) do
      {
        table_description: {
          attribute_definitions: new_table_valid_options[:attribute_definitions],
          table_name: "#{new_table_valid_options[:table_name]}-#{environment_valid.name}",
          key_schema: new_table_valid_options[:key_schema],
          table_status: 'ACTIVE',
          provisioned_throughput: { read_capacity_units: new_table_valid_options[:read_capacity_units],
                                    write_capacity_units: new_table_valid_options[:write_capacity_units] },
          table_arn: 'table_arn',
          local_secondary_indexes: new_table_valid_options[:local_secondary_indexes],
          global_secondary_indexes: [
            {
              index_name: 'CreateDateIndex',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'CreateDate', key_type: 'HASH' },
                           { attribute_name: 'IssueId', key_type: 'RANGE' }],
              projection: {
                projection_type: 'INCLUDE',
                non_key_attributes: %w[Description Status]
              },
              backfilling: false,
              index_status: 'ACTIVE'
            },
            {
              index_name: 'TitleIndex',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'Title', key_type: 'HASH' },
                           { attribute_name: 'IssueId', key_type: 'RANGE' }],
              projection: {
                projection_type: 'KEYS_ONLY'
              },
              backfilling: false,
              index_status: 'ACTIVE'
            },
            {
              index_name: 'DueDateIndex',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'DueDate', key_type: 'HASH' }],
              projection: {
                projection_type: 'ALL'
              },
              backfilling: false,
              index_status: 'ACTIVE'
            }
          ]
        }
      }
    end

    let(:update_table_options) do
      {
        table_name: 'Issues', attribute_definitions:
          [
            { attribute_name: 'IssueId', attribute_type: 'S' },
            { attribute_name: 'Title', attribute_type: 'S' },
            { attribute_name: 'CreateDate', attribute_type: 'S' },
            { attribute_name: 'DueDate', attribute_type: 'S' }
          ],
        key_schema: [{ attribute_name: 'IssueId', key_type: 'HASH' },
                     { attribute_name: 'Title', key_type: 'RANGE' }],
        read_capacity_units: 800, write_capacity_units: 40,
        global_secondary_indexes:
          [
            {
              index_name: 'CreateDateIndex',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'CreateDate', key_type: 'HASH' },
                           { attribute_name: 'IssueId', key_type: 'RANGE' }],
              projection: {
                projection_type: 'INCLUDE',
                non_key_attributes: %w[Description Status]
              }
            },
            { # Index to be updated.
              index_name: 'TitleIndex',
              provisioned_throughput: { read_capacity_units: 16, write_capacity_units: 4 },
              key_schema: [{ attribute_name: 'Title', key_type: 'HASH' },
                           { attribute_name: 'IssueId', key_type: 'RANGE' }],
              projection: {
                projection_type: 'KEYS_ONLY'
              }
            },
            { # Index to be added
              index_name: 'NewIndex',
              provisioned_throughput: { read_capacity_units: 40, write_capacity_units: 4 },
              key_schema: [{ attribute_name: 'CreateDate', key_type: 'HASH' }],
              projection: {
                projection_type: 'ALL'
              }
            }
            # Index to be delete:
            # {
            #  index_name: 'DueDateIndex',
            #  provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
            #  key_schema: [{ attribute_name: 'DueDate', key_type: 'HASH' }],
            #  projection: {
            #    projection_type: 'ALL'
            #  }
            # }
          ],
        local_secondary_indexes:
          [
            { index_name: 'LocalIndex', key_schema: [{ attribute_name: 'Title', key_type: 'HASH' }],
              projection: { projection_type: 'ALL' } }
          ],
        append_environment_on_deploy: true
      }
    end

    def setup
      silence_output
      @fake_sleep = proc { |seconds| puts "fake sleeping for #{seconds} seconds." }
    end

    def teardown
      enable_output
    end

    describe ' when constructing a DynamoTable ' do
      it ' should return successfully with valid supplied arguments. ' do
        table_valid.must_be_instance_of(LambdaWrap::DynamoTable)
      end
      it ' should return successfully with minimal arguments. ' do
        LambdaWrap::DynamoTable.new(table_name: 'minimal').must_be_instance_of(LambdaWrap::DynamoTable)
      end
      it ' should throw an error if table name isnt given. ' do
        options = new_table_valid_options
        options[:table_name] = nil
        proc { LambdaWrap::DynamoTable.new(options) }.must_raise(ArgumentError).to_s.must_match(/table_name/)
      end
      it ' should throw an error if too many LocalSecondaryIndexes are given. ' do
        options = new_table_valid_options
        options[:local_secondary_indexes] = [
          { index_name: 'index1', key_schema: [{ attribute_name: 'Title', key_type: 'HASH' }],
            projection: { projection_type: 'ALL' } },
          { index_name: 'index2', key_schema: [{ attribute_name: 'Title', key_type: 'HASH' }],
            projection: { projection_type: 'ALL' } },
          { index_name: 'index3', key_schema: [{ attribute_name: 'Title', key_type: 'HASH' }],
            projection: { projection_type: 'ALL' } },
          { index_name: 'index4', key_schema: [{ attribute_name: 'Title', key_type: 'HASH' }],
            projection: { projection_type: 'ALL' } },
          { index_name: 'index5', key_schema: [{ attribute_name: 'Title', key_type: 'HASH' }],
            projection: { projection_type: 'ALL' } },
          { index_name: 'index6', key_schema: [{ attribute_name: 'Title', key_type: 'HASH' }],
            projection: { projection_type: 'ALL' } }
        ]
        proc { LambdaWrap::DynamoTable.new(options) }.must_raise(ArgumentError).to_s.must_match(/LocalSecondaryIndexes/)
      end
      it ' should throw an error if too many GlobalSecondaryIndexes are Given. ' do
        options = new_table_valid_options
        options[:global_secondary_indexes].concat(
          [
            {
              index_name: 'DueDateIndex2',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'DueDate', key_type: 'HASH' }],
              projection: {
                projection_type: 'ALL'
              }
            },
            {
              index_name: 'DueDateIndex3',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'DueDate', key_type: 'HASH' }],
              projection: {
                projection_type: 'ALL'
              }
            },
            {
              index_name: 'DueDateIndex4',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'DueDate', key_type: 'HASH' }],
              projection: {
                projection_type: 'ALL'
              }
            },
            {
              index_name: 'DueDateIndex5',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'DueDate', key_type: 'HASH' }],
              projection: {
                projection_type: 'ALL'
              }
            },
            {
              index_name: 'DueDateIndex6',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'DueDate', key_type: 'HASH' }],
              projection: {
                projection_type: 'ALL'
              }
            }
          ]
        )
        proc { LambdaWrap::DynamoTable.new(options) }.must_raise(ArgumentError).to_s
                                                     .must_match(/GlobalSecondaryIndexes/)
      end
      it ' should throw an error if an Index\'s key_schema is not defined in the attribute_definitions ' do
        options = new_table_valid_options
        options[:global_secondary_indexes].concat(
          [
            {
              index_name: 'BadIndex',
              provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'BadAttribute', key_type: 'HASH' }],
              projection: {
                projection_type: 'ALL'
              }
            }
          ]
        )
        proc { LambdaWrap::DynamoTable.new(options) }.must_raise(ArgumentError).to_s
                                                     .must_match(/key_schema are defined in the attribute_definitions/)
      end
      it ' should throw an error if the provisioned throughput of the table or indexes are invalid. ' do
        options = new_table_valid_options
        options[:read_capacity_units] = 0
        proc { LambdaWrap::DynamoTable.new(options) }.must_raise(ArgumentError).to_s.must_match(/ProvisionedThroughput/)
        options = new_table_valid_options
        options[:write_capacity_units] = 0
        proc { LambdaWrap::DynamoTable.new(options) }.must_raise(ArgumentError).to_s.must_match(/ProvisionedThroughput/)
        options = new_table_valid_options
        options[:read_capacity_units] = -1
        proc { LambdaWrap::DynamoTable.new(options) }.must_raise(ArgumentError).to_s.must_match(/ProvisionedThroughput/)
        options = new_table_valid_options
        options[:write_capacity_units] = Float::INFINITY
        proc { LambdaWrap::DynamoTable.new(options) }.must_raise(ArgumentError).to_s.must_match(/ProvisionedThroughput/)
        options = new_table_valid_options
        options[:write_capacity_units] = Math::PI
        proc { LambdaWrap::DynamoTable.new(options) }.must_raise(ArgumentError).to_s.must_match(/ProvisionedThroughput/)
        options = new_table_valid_options
        options[:write_capacity_units] = 1.5
        proc { LambdaWrap::DynamoTable.new(options) }.must_raise(ArgumentError).to_s.must_match(/ProvisionedThroughput/)
        options = new_table_valid_options
        options[:write_capacity_units] = '1'
        proc { LambdaWrap::DynamoTable.new(options) }.must_raise(ArgumentError).to_s.must_match(/ProvisionedThroughput/)
        options = new_table_valid_options
        options[:write_capacity_units] = true
        proc { LambdaWrap::DynamoTable.new(options) }.must_raise(ArgumentError).to_s.must_match(/ProvisionedThroughput/)
        options = new_table_valid_options
        options[:global_secondary_indexes].concat(
          [
            {
              index_name: 'BadThroughputIndex',
              provisioned_throughput: { read_capacity_units: 0, write_capacity_units: 2 },
              key_schema: [{ attribute_name: 'CreateDate', key_type: 'HASH' },
                           { attribute_name: 'IssueId', key_type: 'RANGE' }],
              projection: {
                projection_type: 'INCLUDE',
                non_key_attributes: %w[Description Status]
              }
            }
          ]
        )
        proc { LambdaWrap::DynamoTable.new(options) }.must_raise(ArgumentError).to_s.must_match(/ProvisionedThroughput/)
      end
    end

    describe ' when deploying a DynamoTable ' do
      it ' should return successfully with no necessary updates. ' do
        client = Aws::DynamoDB::Client.new(
          region: 'eu-west-1',
          stub_responses: {
            describe_table: [
              describe_table_response_table_updating1,
              describe_table_response_table_updating1,
              describe_table_response_valid1
            ]
          }
        )

        Kernel.stub :sleep, @fake_sleep do
          table_valid.deploy(environment_valid, client, 'eu-west-1').must_equal('Issues-unittesting')
        end
      end
      it ' should return successfully when creating the table for the first time. ' do
        client = Aws::DynamoDB::Client.new(
          region: 'eu-west-1',
          stub_responses: {
            describe_table: [
              'ResourceNotFoundException',
              describe_table_response_table_updating1,
              describe_table_response_valid1
            ],
            create_table: {}
          }
        )

        Kernel.stub :sleep, @fake_sleep do
          table_valid.deploy(environment_valid, client, 'eu-west-1').must_equal('Issues-unittesting')
        end
      end
      it ' should return successfully when updating a table with new Global Index, an Update to a Global Index, \
\        and Deleting a Global Index. ' do
        client = Aws::DynamoDB::Client.new(
          region: 'eu-west-1',
          stub_responses: {
            describe_table: [
              # initial collection
              describe_table_response_table_updating1,
              describe_table_response_table_updating1,
              describe_table_response_valid1,

              # updated provisioned_throughput
              describe_table_response_table_updating2,
              describe_table_response_valid2,

              # deleted global secondary
              describe_table_response_table_updating3,
              describe_table_response_table_updating3,
              describe_table_response_table_updating3,
              describe_table_response_table_updating3,
              describe_table_response_table_updating3,
              describe_table_response_valid3,

              # Updated Global secondary Index
              describe_table_response_table_updating4,
              describe_table_response_table_updating4,
              describe_table_response_table_updating4,
              describe_table_response_table_updating4,
              describe_table_response_table_updating4,
              describe_table_response_valid4,

              # Created Global Secondary Index
              describe_table_response_table_updating5,
              describe_table_response_table_updating5,
              describe_table_response_table_updating5,
              describe_table_response_table_updating5,
              describe_table_response_table_updating5,
              describe_table_response_table_updating5,
              describe_table_response_table_updating5,
              describe_table_response_table_updating5,
              describe_table_response_valid5
            ]
          }
        )
        Kernel.stub :sleep, @fake_sleep do
          table = LambdaWrap::DynamoTable.new(update_table_options)
          table.deploy(environment_valid, client, 'eu-west-1')
        end
      end
    end
    describe ' when tearing down a DynamoTable ' do
      it ' should return successfully if there is no table to delete. ' do
        client = Aws::DynamoDB::Client.new(
          region: 'eu-west-1',
          stub_responses: {
            describe_table: 'ResourceNotFoundException'
          }
        )
        table_valid.teardown(environment_valid, client, 'eu-west-1').must_equal('Issues-unittesting')
      end
      it ' should return successfully upon successful deletion. ' do
        client = Aws::DynamoDB::Client.new(
          stub_responses: {
            describe_table: describe_table_response_valid1,
            delete_table: {}
          }
        )
        table_valid.deploy(environment_valid, client, 'eu-west-1').must_equal('Issues-unittesting')
      end
    end
    describe ' when deleting a DynamoTable ' do
      it ' should return successfully if there is no table to delete. ' do
        client = Aws::DynamoDB::Client.new(
          stub_responses: {
            list_tables: [
              {
                table_names: %w[Orders Products Friends],
                last_evaluated_table_name: 'Friends'
              },
              {
                table_names: %w[Foo Bar]
              }
            ],
            delete_table: 'RuntimeError'
          }
        )
        table_valid.delete(client, 'eu-west-1').must_equal(0)
      end
      it ' should return successfully and delete 1 table if not appending environment name. ' do
        client = Aws::DynamoDB::Client.new(
          stub_responses: {
            list_tables: [
              {
                table_names: %w[Orders Products Friends],
                last_evaluated_table_name: 'Friends'
              },
              {
                table_names: %w[Foo Bar Issues]
              }
            ],
            describe_table: describe_table_response_valid1,
            delete_table: {}
          }
        )
        table_valid.delete(client, 'eu-west-1').must_equal(1)
      end
      it ' should return successfully and delete 3 tables if appending environment name. ' do
        client = Aws::DynamoDB::Client.new(
          stub_responses: {
            list_tables: [
              {
                table_names: %w[Orders Products Friends Issues-Staging],
                last_evaluated_table_name: 'Friends'
              },
              {
                table_names: %w[Foo Bar Issues-unittesting Issues-Production]
              }
            ],
            describe_table: [
              {
                table:
                  {
                    table_name: 'Issues-Staging',
                    table_status: 'ACTIVE'
                  }
              },
              {
                table:
                  {
                    table_name: 'Issues-unittesting',
                    table_status: 'ACTIVE'
                  }
              },
              {
                table:
                  {
                    table_name: 'Issues-Production',
                    table_status: 'ACTIVE'
                  }
              }
            ],
            delete_table: {}
          }
        )
        table_valid.delete(client, 'eu-west-1').must_equal(3)
      end
    end
  end
end
