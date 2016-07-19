require 'aws-sdk'

module LambdaWrap
  ##
  # The S3BucketManager would have functions to help add policies, CORS etc to S3 bucket.
  class S3BucketManager
    #
    # The constructor creates an instance of s3 bucket
    # * Validating basic AWS configuration
    # * Creating the underlying client to interact with the AWS SDK.
    # * Defining the temporary path of the api-gateway-importer jar file
    def initialize
      @s3bucket = Aws::S3::Client.new()
    end

    ##
    # Adds policy to the bucket
    #
    # *Arguments*
    # [s3_bucket_name]	S3 bucket name.
    # [policy]	Policy to be added to the bucket
    def setup_policy(s3_bucket_name, policy)
      # Validate the parameters
      raise "S3 bucket is not provided" unless s3_bucket_name
      raise "Policy json is not provided" unless policy

      @s3bucket.put_bucket_policy({
        bucket: s3_bucket_name,
        policy: policy.to_json
      })
      puts "Created/Updated policy: #{policy} in S3 bucket #{s3_bucket_name}"
    end

  end
end
