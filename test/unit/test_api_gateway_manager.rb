require './test/helper.rb'
require 'minitest/autorun'
require 'minitest/reporters'
require 'aws-sdk'
require 'lambda_wrap'
Minitest::Reporters.use!

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


end
