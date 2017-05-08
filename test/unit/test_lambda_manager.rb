require 'minitest/autorun'
require 'aws-sdk'
require 'lambda_wrap'

describe LambdaWrap::Lambda do
  let(:stubbed_lambda_client) { Aws::Lambda::Client.new(stub_responses: true) }
  let(:stubbed_DynamoDB_client) { Aws::DynamoDB::Client.new(stub_responses: true) }
  let(:stubbed_APIGateway_client) { Aws::APIGateway::Client.new(stub_responses: true) }

  # let(:lambda_1) { Lambda.new(lambda_name: 'Lambda1', handler: 'handler1', )}

  describe ' When constructing the Lambda ' do
    it ' must throw an error if  the Lambda Name is not given. ' do
      proc { LambdaWrap::Lambda.new(foo: 'bar') }
        .must_raise(ArgumentError).to_s
        .must_match(/lambda_name/)
    end
  end
end
