require './test/helper.rb'
require 'minitest/autorun'
require 'minitest/reporters'
require 'aws-sdk'
require 'lambda_wrap'
Minitest::Reporters.use!

class TestLambda < Minitest::Test
  describe LambdaWrap::Lambda do
    let(:lambda_valid) do
      LambdaWrap::Lambda.new(
        lambda_name: 'LambdaValid', handler: 'handlerValid', role_arn: 'role_arnValid',
        path_to_zip_file: 'valid/path/to/file.zip', runtime: 'nodejs4.3', description: 'descriptionValid',
        timeout: 30, memory_size: 256, subnet_ids: %w[subnet1 subnet2 subnet3],
        security_group_ids: ['securitygroupValid'], delete_unreferenced_versions: false
      )
    end

    let(:environment_valid) do
      LambdaWrap::Environment.new('UnitTestingValid', { variable: 'valueValid' },
                                  'My UnitTesting EnvironmentValid')
    end

    let(:environment_invalid) do
      LambdaWrap::Environment.new('UnitTestingEInvalid', {}, 'My invalid Env')
    end

    let(:api1) do
      LambdaWrap::API.new(
        lambda_client: stubbed_lambda_client, dynamo_client: stubbed_DynamoDB_client,
        api_gateway_client: stubbed_APIGateway_client
      )
    end

    def setup
      silence_output
      @stubbed_lambda_client = Aws::Lambda::Client.new(region: 'eu-west-1', stub_responses: true)
      @stubbed_dynamo_client = Aws::DynamoDB::Client.new(stub_responses: true)
      @stubbed_apig_client = Aws::APIGateway::Client.new(stub_responses: true)
    end

    def teardown
      enable_output
    end

    describe ' When constructing the Lambda ' do
      it ' should throw an error if the Lambda Name is not given. ' do
        proc { LambdaWrap::Lambda.new(foo: 'bar') }
          .must_raise(ArgumentError).to_s
          .must_match(/lambda_name/)
      end

      it ' should throw an error if the Handler is not given. ' do
        proc { LambdaWrap::Lambda.new(foo: 'bar') }
          .must_raise(ArgumentError).to_s
          .must_match(/lambda_name/)
      end

      it ' should throw an error if the RoleArn is not given. ' do
        proc { LambdaWrap::Lambda.new(lambda_name: 'Lambda2', handler: 'handler2') }
          .must_raise(ArgumentError).to_s
          .must_match(/role_arn/)
      end

      it ' should throw an error if the PathToZipFile is not given. ' do
        proc { LambdaWrap::Lambda.new(lambda_name: 'Lambda2', handler: 'handler2', role_arn: 'role') }
          .must_raise(ArgumentError).to_s
          .must_match(/path_to_zip_file/)
      end

      it ' should throw an error if the Runtime is not given. ' do
        proc do
          LambdaWrap::Lambda.new(
            lambda_name: 'Lambda2', handler: 'handler2', role_arn: 'role', path_to_zip_file: 'path/file.zip'
          )
        end
          .must_raise(ArgumentError).to_s
          .must_match(/runtime/)
      end

      it ' should throw an error if an invalid Runtime is given. ' do
        proc do
          LambdaWrap::Lambda.new(
            lambda_name: 'Lambda2', handler: 'handler2', role_arn: 'role', path_to_zip_file: 'path/file.zip',
            runtime: 'c++'
          )
        end
          .must_raise(ArgumentError).to_s
          .must_match(/Runtime/)
      end

      it ' should throw an error if an invalid memory size is given. ' do
        proc do
          LambdaWrap::Lambda.new(
            lambda_name: 'Lambda2', handler: 'handler2', role_arn: 'role', path_to_zip_file: 'path/file.zip',
            runtime: 'nodejs4.3', memory_size: 64
          )
        end
          .must_raise(ArgumentError).to_s
          .must_match(/Memory Size/)

        proc do
          LambdaWrap::Lambda.new(
            lambda_name: 'Lambda2', handler: 'handler2', role_arn: 'role', path_to_zip_file: 'path/file.zip',
            runtime: 'nodejs4.3', memory_size: 129
          )
        end
          .must_raise(ArgumentError).to_s
          .must_match(/Memory Size/)

        proc do
          LambdaWrap::Lambda.new(
            lambda_name: 'Lambda2', handler: 'handler2', role_arn: 'role', path_to_zip_file: 'path/file.zip',
            runtime: 'nodejs4.3', memory_size: 64_000
          )
        end
          .must_raise(ArgumentError).to_s
          .must_match(/Memory Size/)
      end

      it ' should throw an error if an invalid VPC config is given is given. ' do
        proc do
          LambdaWrap::Lambda.new(
            lambda_name: 'Lambda2', handler: 'handler2', role_arn: 'role', path_to_zip_file: 'path/file.zip',
            runtime: 'nodejs4.3', subnet_ids: [], security_group_ids: %w[security_group_id1 2]
          )
        end
          .must_raise(ArgumentError).to_s
          .must_match(/VPC/)

        proc do
          LambdaWrap::Lambda.new(
            lambda_name: 'Lambda2', handler: 'handler2', role_arn: 'role', path_to_zip_file: 'path/file.zip',
            runtime: 'nodejs4.3', subnet_ids: %w[1 2 3], security_group_ids: []
          )
        end
          .must_raise(ArgumentError).to_s
          .must_match(/VPC/)
      end
    end

    describe ' when deploying the Lambda ' do
      it ' should throw an error a LambdaWrap::Environment is not given. ' do
        proc { lambda_valid.deploy('Not An Environment') }
          .must_raise(ArgumentError).to_s
          .must_match(/LambdaWrap::Environment/)
      end

      it ' should throw an error if there is no Lambda Client initialized. ' do
        proc {
          lambda_valid.deploy(environment_valid)
        }
          .must_raise(Exception).to_s
          .must_match(/Lambda Client/)
      end

      it ' should throw an error if the zip file does not exist. ' do
        proc do
          bad_zip_lambda = LambdaWrap::Lambda.new(
            lambda_name: 'Lambda1', handler: 'handler1', role_arn: 'role_arn1',
            path_to_zip_file: './BADPATH', runtime: 'nodejs4.3', description: 'description1',
            timeout: 30, memory_size: 256, subnet_ids: %w[subnet1 subnet2 subnet3],
            security_group_ids: ['securitygroup1'], delete_unreferenced_versions: true
          )
          bad_zip_lambda.deploy(environment_invalid, @stubbed_lambda_client)
        end
          .must_raise(ArgumentError).to_s
          .must_match(/Zip File does not exist/)
      end
      it ' should create a new function and new alias successfully.' do
        # Stubs exist?
        File.stub :exist?, true do
          lambda_client = Aws::Lambda::Client.new(
            stub_responses: {
              get_function: 'ResourceNotFoundException',
              create_function: { version: '1' },
              list_aliases: { aliases: [{ name: 'WrongName' }] },
              create_alias: { name: 'UnitTestingEnvironmentValid' }
            }
          )
          lambda_valid.deploy(environment_valid, lambda_client).must_equal(true)
        end
      end

      it ' should update function code, configuration and create a new alias successfully. ' do
        File.stub :exist?, true do
          lambda_client = Aws::Lambda::Client.new(
            stub_responses: {
              get_function: { configuration: { version: '3' } },
              update_function_configuration: { version: '3' },
              update_function_code: { version: '4' },
              list_aliases: { aliases: [{ name: 'WrongName' }] },
              create_alias: { name: 'UnitTestingEnvironmentValid' }
            }
          )
          lambda_valid.deploy(environment_valid, lambda_client).must_equal(true)
        end
      end

      it ' should update function code, configuration, and alias successfully.' do
        File.stub :exist?, true do
          lambda_client = Aws::Lambda::Client.new(
            stub_responses: {
              get_function: { configuration: { version: '3' } },
              update_function_configuration: { version: '3' },
              update_function_code: { version: '4' },
              list_aliases: { aliases: [{ name: 'UnitTestingEnvironmentValid' }, { name: 'WrongName' }] },
              update_alias: { name: 'UnitTestingEnvironmentValid' }
            }
          )
          lambda_valid.deploy(environment_valid, lambda_client).must_equal(true)
        end
      end

      it ' should update function code, configuration, and alias successfully, and remove unused versions.' do
        File.stub :exist?, true do
          lambda_client = Aws::Lambda::Client.new(
            stub_responses: {
              get_function: { configuration: { version: '3' } },
              update_function_configuration: { version: '3' },
              update_function_code: { version: '4' },
              list_aliases: { aliases: [{ function_version: '1', name: 'UnitTestingEnvironmentValid' },
                                        { function_version: '3', name: 'WrongName' },
                                        { function_version: '3', name: 'DupAlias' }] },
              update_alias: { name: 'UnitTestingEnvironmentValid' },
              list_versions_by_function: { versions: [{ version: '1' }, { version: '2' }, { version: '3' }] },
              delete_function: {}
            }
          )
          lambda_valid_with_delete = LambdaWrap::Lambda.new(
            lambda_name: 'LambdaValid', handler: 'handlerValid', role_arn: 'role_arnValid',
            path_to_zip_file: 'valid/path/to/file.zip', runtime: 'nodejs4.3', description: 'descriptionValid',
            timeout: 30, memory_size: 256, subnet_ids: %w[subnet1 subnet2 subnet3],
            security_group_ids: ['securitygroupValid'], delete_unreferenced_versions: true
          )

          lambda_valid_with_delete.deploy(environment_valid, lambda_client).must_equal(true)
        end
      end
    end

    describe ' when tearing-down the Lambda ' do
      it ' should throw an error a LambdaWrap::Environment is not given. ' do
        proc { lambda_valid.teardown('Not An Environment', @stubbed_lambda_client) }
          .must_raise(ArgumentError).to_s
          .must_match(/LambdaWrap::Environment/)
      end

      it ' should delete the alias successfully. ' do
        lambda_client = Aws::Lambda::Client.new(
          stub_responses: {
            delete_alias: {}
          }
        )
        lambda_valid.teardown(environment_valid, lambda_client).must_equal(true)
      end

      it ' should delete the alias successfully and delete unused versions. ' do
        lambda_client = Aws::Lambda::Client.new(
          stub_responses: {
            list_aliases: { aliases: [{ function_version: '3', name: 'WrongName' },
                                      { function_version: '3', name: 'DupAlias' }] },
            update_alias: { name: 'UnitTestingEnvironmentValid' },
            list_versions_by_function: { versions: [{ version: '1' }, { version: '2' }, { version: '3' }] },
            delete_alias: {},
            delete_function: {}
          }
        )
        lambda_valid_with_delete = LambdaWrap::Lambda.new(
          lambda_name: 'LambdaValid', handler: 'handlerValid', role_arn: 'role_arnValid',
          path_to_zip_file: 'valid/path/to/file.zip', runtime: 'nodejs4.3', description: 'descriptionValid',
          timeout: 30, memory_size: 256, subnet_ids: %w[subnet1 subnet2 subnet3],
          security_group_ids: ['securitygroupValid'], delete_unreferenced_versions: true
        )
        lambda_valid_with_delete.teardown(environment_valid, lambda_client).must_equal(true)
      end
    end

    describe ' when deleting the Lambda ' do
      it ' successfully delete the function. ' do
        lambda_client = Aws::Lambda::Client.new(
          stub_responses: {
            get_function: { configuration: {} },
            delete_function: {}
          }
        )
        lambda_valid.delete(lambda_client).must_equal(true)
      end

      it ' should successfully delete the Lambda if it doesnt exist. ' do
        lambda_client = Aws::Lambda::Client.new(
          stub_responses: {
            get_function: 'ResourceNotFoundException',
            delete_function: {}
          }
        )
        lambda_valid.delete(lambda_client).must_equal(true)
      end
    end
  end
end
