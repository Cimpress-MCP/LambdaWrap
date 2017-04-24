require 'aws-sdk'

module LambdaWrap
  class API
    attr_reader :lambdas
    attr_reader :dynamo_tables
    attr_reader :api_gateways

    def initialize(access_key_id = nil, secret_access_key = nil, region = nil)
      access_key_id = access_key_id || ENV['AWS_ACCESS_KEY_ID'] || ENV['ACCESS_KEY']
      secret_access_key = secret_access_key || ENV['AWS_SECRET_ACCESS_KEY'] || ENV['SECRET_KEY']
      @region = region['region'] || ENV['AWS_REGION'] || ENV['AMAZON_REGION'] || ENV['AWS_DEFAULT_REGION']
      @credentials = Aws::Credentials.new(access_key_id, secret_access_key)
      @lambdas = []
      @dynamo_db_tables = []
      @api_gateways = []
    end

    def add_lambda(new_lambda)
      parameter_guard(new_lambda, LambdaWrap::Lambda, 'LambdaWrap::Lambda')
      lambdas << new_lambda
    end

    def add_dynamo_table(new_table)
      parameter_guard(new_table, LambdaWrap::DynamoTable, 'LambdaWrap::DynamoTable')
      dynamo_tables << new_table
    end

    def add_api_gateway(new_api_gateway)
      parameter_guard(new_api_gateway, LambdaWrap::ApiGateway, 'LambdaWrap::ApiGateway')
      api_gateways << new_api_gateway
    end

    private

    def parameter_guard(parameter, type, type_name)
      return if parameter.is_a(type)
      raise ArgumentError, "Must pass a #{type_name} to the API Manager. Got: #{parameter}"
    end
  end
end
