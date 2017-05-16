module LambdaWrap
  # Super Abstract Class for all AWS services and their calls.
  # @abstract
  # @since 1.0
  class AwsService
    def deploy(environment, client, region = 'AWS_REGION')
      unless environment.is_a?(LambdaWrap::Environment)
        raise ArgumentError, 'Must pass a LambdaWrap::Environment class.'
      end
      @client = client
      @region = region
      client_guard
    end

    def teardown(environment, client, region = 'AWS_REGION')
      unless environment.is_a?(LambdaWrap::Environment)
        raise ArgumentError, 'Must pass a LambdaWrap::Environment class.'
      end
      @client = client
      @region = region
      client_guard
    end

    def delete(client, region = 'AWS_REGION')
      @client = client
      @region = region
      client_guard
    end

    private

    def client_guard
      unless @client.class == Aws::Lambda::Client || @client.class == Aws::DynamoDB::Client ||
             @client.class == Aws::APIGateway::Client
        raise ArgumentError, 'AWS client not initialized.'
      end
      raise ArgumentError, 'Invalid region' if @region.empty? || !Aws.partition('aws').region(@region)
    end
  end
end
