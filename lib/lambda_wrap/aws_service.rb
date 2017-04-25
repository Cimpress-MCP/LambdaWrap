module LambdaWrap
  ##
  # Superclass for all AWS services and their calls.
  class AwsService
    def deploy(options)
      return if options[:environment].is_a(LambdaWrap::Environment)
      raise ArgumentError, 'Must pass a LambdaWrap::Environment class.'
    end

    def teardown(options)
      return if options[:environment].is_a(LambdaWrap::Environment)
      raise ArgumentError, 'Must pass a LambdaWrap::Environment class.'
    end

    def delete() end
  end
end
