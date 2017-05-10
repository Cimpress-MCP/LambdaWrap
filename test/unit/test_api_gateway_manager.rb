require './test/helper.rb'

class TestApiGateway < Minitest::Test
  def setup
    silence_output
    @stubbed_lambda_client = Aws::Lambda::Client.new(region: 'eu-west-1', stub_responses: true)
    @stubbed_dynamo_client = Aws::DynamoDB::Client.new(stub_responses: true)
    @stubbed_apig_client = Aws::APIGateway::Client.new(stub_responses: true)
  end

  def teardown
    enable_output
  end

  describe ' when constructiong the API Gateway ' do
    it ' should create successfully with all valid values given.' do
      apig_under_test = LambdaWrap::ApiGateway.new(swagger_file_path: './test/data/swagger_valid_1.yaml',
                                                   import_mode: 'merge')
      apig_under_test.must_be_instance_of(LambdaWrap::ApiGateway)
    end
  end
end
