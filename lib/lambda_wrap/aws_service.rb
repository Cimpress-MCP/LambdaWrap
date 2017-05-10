module LambdaWrap
  ##
  # Superclass for all AWS services and their calls.
  class AwsService
    def deploy(environment, client = nil, region = '')
      unless environment.is_a?(LambdaWrap::Environment)
        raise ArgumentError, 'Must pass a LambdaWrap::Environment class.'
      end
      @client = client
      @region = region
      client_guard
    end

    def teardown(environment, client = nil, region = '')
      unless environment.is_a?(LambdaWrap::Environment)
        raise ArgumentError, 'Must pass a LambdaWrap::Environment class.'
      end
      @client = client
      @region = region
      client_guard
    end

    def delete(client = nil, region = '')
      @client = client
      @region = region
      client_guard
    end

    private

    def client_guard
      raise ArgumentError, 'AWS client not initialized.' unless @client
      raise ArgumentError, 'Region not given' if @region.empty?
    end
  end
end
