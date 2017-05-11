require './test/helper.rb'

class TestApi < Minitest::Test
  describe LambdaWrap::API do
    def setup
      silence_output
      @default_region = 'eu-west-1'
      @stubbed_lambda_client = Aws::Lambda::Client.new(region: @default_region, stub_responses: true)
      @stubbed_dynamo_client = Aws::DynamoDB::Client.new(region: @default_region, stub_responses: true)
      @stubbed_apig_client = Aws::APIGateway::Client.new(region: @default_region, stub_responses: true)

      @lambda_mock = Minitest::Mock.new
      @table_mock = Minitest::Mock.new
      @apig_mock = Minitest::Mock.new

      # Capture Environment Variables. Must be exhaustive....
      @old_aws_access_key_id = ENV['AWS_ACCESS_KEY_ID']
      @old_access_key = ENV['ACCESS_KEY']
      @old_aws_secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']
      @old_secret_key = ENV['SECRET_KEY']
      @old_aws_region = ENV['AWS_REGION']
      @old_amazon_region = ENV['AMAZON_REGION']
      @old_aws_default_region = ENV['AWS_DEFAULT_REGION']

      # Nil out those values so they can be used in tests (as though they weren't set at all)
      ENV['AWS_ACCESS_KEY_ID'] = nil
      ENV['ACCESS_KEY'] = nil
      ENV['AWS_SECRET_ACCESS_KEY'] = nil
      ENV['SECRET_KEY'] = nil
      ENV['AWS_REGION'] = nil
      ENV['AMAZON_REGION'] = nil
      ENV['AWS_DEFAULT_REGION'] = nil
    end

    def teardown
      enable_output

      # verify mocks.
      @lambda_mock.verify
      @table_mock.verify
      @apig_mock.verify

      # restore environment variables
      ENV['AWS_ACCESS_KEY_ID'] = @old_aws_access_key_id
      ENV['ACCESS_KEY'] = @old_access_key
      ENV['AWS_SECRET_ACCESS_KEY'] = @old_aws_secret_access_key
      ENV['SECRET_KEY'] = @old_secret_key
      ENV['AWS_REGION'] = @old_aws_region
      ENV['AMAZON_REGION'] = @old_amazon_region
      ENV['AWS_DEFAULT_REGION'] = @old_aws_default_region
    end

    let(:stubbed_api) do
      LambdaWrap::API.new(
        lambda_client: @stubbed_lambda_client, dynamo_client: @stubbed_dynamo_client,
        api_gateway_client: @stubbed_apig_client, region: 'eu-west-1'
      )
    end

    let(:initialized_api) do
      @lambda_mock.expect(:is_a?, true, [LambdaWrap::Lambda])
      @table_mock.expect(:is_a?, true, [LambdaWrap::DynamoTable])
      @apig_mock.expect(:is_a?, true, [LambdaWrap::ApiGateway])
      init_api = stubbed_api
      init_api.add_lambda(@lambda_mock)
      init_api.add_dynamo_table(@table_mock)
      init_api.add_api_gateway(@apig_mock)
      init_api
    end

    let(:environment_valid) do
      LambdaWrap::Environment.new('UnitTestingValid', { variable: 'valueValid' },
                                  'My UnitTesting EnvironmentValid')
    end

    describe ' when constructiong an API object ' do
      it ' should return successfully with stubbed options. ' do
        stubbed_api.must_be_instance_of(LambdaWrap::API)
      end
      it ' should return successfully with valid options passed in' do
        api = LambdaWrap::API.new(
          access_key_id: 'access_key_id', secret_access_key: 'secret_access_key', region: 'eu-west-1'
        )
        api.must_be_instance_of(LambdaWrap::API)
      end
      it ' should return successfully with valid Environment Variables (first conditions...).' do
        ENV['AWS_ACCESS_KEY_ID'] = 'aws_access_key_id'
        ENV['AWS_SECRET_ACCESS_KEY'] = 'aws_secret_access_key'
        ENV['AWS_REGION'] = 'eu-west-1'
        api = LambdaWrap::API.new
        api.must_be_instance_of(LambdaWrap::API)
      end
      it ' should return successfully with valid Environment Variables (second conditions...).' do
        ENV['ACCESS_KEY'] = 'aws_access_key_id'
        ENV['SECRET_KEY'] = 'aws_secret_access_key'
        ENV['AMAZON_REGION'] = 'eu-west-1'
        api = LambdaWrap::API.new
        api.must_be_instance_of(LambdaWrap::API)
      end
      it ' should return successfully with valid Environment Variables (third conditions...).' do
        ENV['ACCESS_KEY'] = 'aws_access_key_id'
        ENV['SECRET_KEY'] = 'aws_secret_access_key'
        ENV['AWS_DEFAULT_REGION'] = 'eu-west-1'
        api = LambdaWrap::API.new
        api.must_be_instance_of(LambdaWrap::API)
      end
      it ' should throw an error if the credentials arent given (access key)' do
        proc { LambdaWrap::API.new }.must_raise(ArgumentError).to_s.must_match(/AWS Access Key ID/)
      end
      it ' should throw an error if the credentials arent given (secret key)' do
        proc { LambdaWrap::API.new(access_key_id: 'access_key_id') }.must_raise(ArgumentError).to_s
                                                                    .must_match(/AWS Secret Key/)
      end
      it ' should throw an error if the region is not given' do
        proc { LambdaWrap::API.new(access_key_id: 'access_key_id', secret_access_key: 'secret_access_key') }
          .must_raise(ArgumentError).to_s
          .must_match(/AWS Region/)
      end
    end
    describe ' when adding lambda ' do
      it ' should add one successfully. ' do
        @lambda_mock.expect(:is_a?, true, [LambdaWrap::Lambda])
        stubbed_api.add_lambda(@lambda_mock)
        stubbed_api.lambdas.length.must_equal(1)
      end
      it ' should add an array successfully. ' do
        @lambda_mock.expect(:is_a?, true, [LambdaWrap::Lambda])
        @lambda_mock.expect(:is_a?, true, [LambdaWrap::Lambda])
        stubbed_api.add_lambda([@lambda_mock, @lambda_mock])
        stubbed_api.lambdas.length.must_equal(2)
      end
      it ' should add a splat successfully. ' do
        @lambda_mock.expect(:is_a?, true, [LambdaWrap::Lambda])
        @lambda_mock.expect(:is_a?, true, [LambdaWrap::Lambda])
        @lambda_mock.expect(:is_a?, true, [LambdaWrap::Lambda])
        stubbed_api.add_lambda(@lambda_mock, @lambda_mock, @lambda_mock)
        stubbed_api.lambdas.length.must_equal(3)
      end
      it ' should not add non Lambdas. ' do
        @lambda_mock.expect(:is_a?, true, [LambdaWrap::Lambda])
        proc { stubbed_api.add_lambda(@lambda_mock, foo: 'bar') }.must_raise(ArgumentError)
      end
    end
    describe ' when adding a table ' do
      it ' should add one successfully. ' do
        @table_mock.expect(:is_a?, true, [LambdaWrap::DynamoTable])
        stubbed_api.add_dynamo_table(@table_mock)
        stubbed_api.dynamo_tables.length.must_equal(1)
      end
      it ' should add an array successfully. ' do
        @table_mock.expect(:is_a?, true, [LambdaWrap::DynamoTable])
        @table_mock.expect(:is_a?, true, [LambdaWrap::DynamoTable])
        stubbed_api.add_dynamo_table([@table_mock, @table_mock])
        stubbed_api.dynamo_tables.length.must_equal(2)
      end
      it ' should add a splat successfully. ' do
        @table_mock.expect(:is_a?, true, [LambdaWrap::DynamoTable])
        @table_mock.expect(:is_a?, true, [LambdaWrap::DynamoTable])
        @table_mock.expect(:is_a?, true, [LambdaWrap::DynamoTable])
        stubbed_api.add_dynamo_table(@table_mock, @table_mock, @table_mock)
        stubbed_api.dynamo_tables.length.must_equal(3)
      end
      it ' should not add non tables. ' do
        @table_mock.expect(:is_a?, true, [LambdaWrap::DynamoTable])
        proc { stubbed_api.add_dynamo_table(@table_mock, 'NotATable') }.must_raise(ArgumentError)
      end
    end
    describe ' when adding API Gateways ' do
      it ' should add one successfully. ' do
        @apig_mock.expect(:is_a?, true, [LambdaWrap::ApiGateway])
        stubbed_api.add_api_gateway(@apig_mock)
        stubbed_api.api_gateways.length.must_equal(1)
      end
      it ' should add an array successfully. ' do
        @apig_mock.expect(:is_a?, true, [LambdaWrap::ApiGateway])
        @apig_mock.expect(:is_a?, true, [LambdaWrap::ApiGateway])
        stubbed_api.add_api_gateway([@apig_mock, @apig_mock])
        stubbed_api.api_gateways.length.must_equal(2)
      end
      it ' should add a splat successfully. ' do
        @apig_mock.expect(:is_a?, true, [LambdaWrap::ApiGateway])
        @apig_mock.expect(:is_a?, true, [LambdaWrap::ApiGateway])
        @apig_mock.expect(:is_a?, true, [LambdaWrap::ApiGateway])
        stubbed_api.add_api_gateway(@apig_mock, @apig_mock, @apig_mock)
        stubbed_api.api_gateways.length.must_equal(3)
      end
      it ' should not add non-APIGateways. ' do
        proc { stubbed_api.add_api_gateway(false) }.must_raise(ArgumentError)
      end
    end
    describe ' when deploying ' do
      it ' should not do anything if no Services have been added. ' do
        stubbed_api.deploy(environment_valid)
      end
      it ' should throw an error if an Environment is not given. ' do
        proc { initialized_api.deploy('NotAnEnvironment') }.must_raise(ArgumentError).to_s
                                                           .must_match(/LambdaWrap::Environment/)
      end
      it ' should deploy all services successfully. ' do
        @lambda_mock.expect(:deploy, true, [environment_valid, @stubbed_lambda_client, @default_region])
        @table_mock.expect(:deploy, true, [environment_valid, @stubbed_dynamo_client, @default_region])
        @apig_mock.expect(:deploy, true, [environment_valid, @stubbed_apig_client, @default_region])
        initialized_api.deploy(environment_valid).must_equal(true)
      end
    end
    describe ' when tearing-down ' do
      it ' shoud not do anything if no Services have been added. ' do
        stubbed_api.teardown(environment_valid)
      end
      it ' should teardown all services successfully. ' do
        @lambda_mock.expect(:teardown, true, [environment_valid, @stubbed_lambda_client, @default_region])
        @table_mock.expect(:teardown, true, [environment_valid, @stubbed_dynamo_client, @default_region])
        @apig_mock.expect(:teardown, true, [environment_valid, @stubbed_apig_client, @default_region])
        initialized_api.teardown(environment_valid).must_equal(true)
      end
    end
    describe ' when deleting ' do
      it ' should not do anything if no services have been added. ' do
        stubbed_api.delete
      end
      it ' should delete all services successfully. ' do
        @lambda_mock.expect(:delete, true, [@stubbed_lambda_client, @default_region])
        @table_mock.expect(:delete, true, [@stubbed_dynamo_client, @default_region])
        @apig_mock.expect(:delete, true, [@stubbed_apig_client, @default_region])
        initialized_api.delete.must_equal(true)
      end
    end
  end
end
