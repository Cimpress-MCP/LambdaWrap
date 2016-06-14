require 'aws-sdk'

##
# LambdaWrap is a ruby gem that simplifies deployment of AWS Lambda functions that are invoked through AWS API Gateway
# and optionally include a DynamoDB backend.
module LambdaWrap
  # Helper class to ensure valid configuration of AWS.
  # This class is intended for internal use only, but clients can call it before calling any other functionality
  # to ensure early failure.
  class AwsSetup
    # Validates that the setup is correct and that the bundled AWS certificate is used for subsequent calls
    # to the AWS SDK
    #
    # *Required environment variables*
    # [AWS_REGION]              A valid AWS region to use during configuration.
    def validate
      # validate settings
      raise 'AWS_REGION not set' unless ENV['AWS_REGION']
      Aws.use_bundled_cert!
    end
  end
end
