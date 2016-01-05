require 'aws-sdk'

module LambdaWrap

    class AwsSetup
        
        def validate()
            
            # validate settings
            raise 'AWS_ACCESS_KEY_ID not set' if !ENV['AWS_ACCESS_KEY_ID']
            raise 'AWS_SECRET_ACCESS_KEY not set' if !ENV['AWS_SECRET_ACCESS_KEY']
            raise 'AWS_REGION not set' if !ENV['AWS_REGION']

            Aws::use_bundled_cert!
            
        end
        
    end
    
end