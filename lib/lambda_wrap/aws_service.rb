module LambdaWrap
  ##
  # Superclass for all AWS services and their calls.
  class AwsService
    def deploy(environment, client = nil)
      unless environment.is_a?(LambdaWrap::Environment)
        raise ArgumentError, 'Must pass a LambdaWrap::Environment class.'
      end
      @client = client
      client_guard
    end

    def teardown(environment, client = nil)
      unless environment.is_a?(LambdaWrap::Environment)
        raise ArgumentError, 'Must pass a LambdaWrap::Environment class.'
      end
      @client = client
      client_guard
    end

    def delete(client = nil)
      @client = client
      client_guard
    end

    private

    def client_guard
      raise Exception, 'Aws client not initialized.' unless @client
    end
  end
end
