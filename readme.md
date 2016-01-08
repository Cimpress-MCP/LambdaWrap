# LambdaWrap

A ruby library to simplify deployment of a serverless based on AWS Lambda, AWS API Gateway and AWS DynamoDB.

LambdaWrap is a very simple way to manage and automate deployment of AWS Lambda functions and related functionality. It is targeted to simple use cases and focuses only on deployment automation. It's primary goal is to support developers who want to be able to spend less than 1h on infrastructure and focus on the actual value deliver of their web service.

Technically, it uses the [AWS SDK](https://aws.amazon.com/sdk-for-ruby/) directly and avoids complexities such as [AWS Cloudformation](https://aws.amazon.com/cloudformation/). Due to its focus on simplifying deployment, it has no built in support to run the functions locally, such as [serverless](https://github.com/serverless/serverless) has.

## Install

To install, call `gem install lambda_wrap`.

## Using LambdaWrap

LambdaWrap makes several assumptions how you structure your project, mainly to simplify this gem and avoid building a complex wrapper around the AWS SDK. However, we're excited to hear about your additional use cases, and welcome direct contributions or feature requests.

### Prerequisites

1. A `.\Gemfile` containing the dependency on your preferred version of `lambda_wrap`. Call `bundle install` to install the gem.
2. Have a `package.json` file in the root directory in case the source depends on additional packages. A call to `npm install` will install the dependencies in `.\node_modules`
3. Include `lambda_wrap` in your ruby script / rakefile that invokes LambdaWrap.
4. Store all files in a single source directory, for example `src`.
5. Compile and upload a version of [aws-apigateway-importer](https://github.com/awslabs/aws-apigateway-importer) on an S3 bucket. LambdaWrap automatically downloads it when api-gateway-importer is needed, and we'll switch over to a public place once aws-apigateway-importer binaries are hosted.
6. Have java in your path to execute aws-apigateway-importer.

### Using LambdaWrap

See the documentation or source code for detailed usage. But the following lines provide an example how a rakefile can look like:

```ruby
task :deploy, :environment do |t, args|
  
  env = args[:environment]
  api_name = 'LambdaWrapService'
  
  # publish dynamoDB database
  attributes = [{ attribute_name: "Key", attribute_type: "S" }]
  keyschema = [{ attribute_name: "Key", key_type: "HASH" }]
  LambdaWrap::DynamoDbManager.new().publish_database('myservice-' + env, attributes, keyschema, 1, 1)
  
  # package functions
  LambdaWrap::LambdaManager.new().package('package', 'package.zip', ['func1.js', 'func2.js'], ['async'])
  
  # publish package to s3
  s3_version_id = LambdaWrap::LambdaManager.new().publish_lambda_to_s3('package.zip', 'artifacts', 'lambda/service.zip')
  
  # deploy package
  func_version = deploy_lambda(s3_version_id, 'func1', 'func1.handler')
  promote_lambda('func1', func_version, env)
  
  # configure API Gateway
  ag_mgr = LambdaWrap::ApiGatewayManager.new()
  ag_mgr.download_apigateway_importer('artifacts', 'tools/aws-apigateway-importer-1.0.3-SNAPSHOT-jar-with-dependencies.jar')
  uri = ag_mgr.setup_apigateway(api_name, env, 'swagger_doc.json')
  
  # notify success
  puts "API gateway with api name set to #{api_name} and environment #{env} is available at #{uri}"
  
  # As additional step, integration tests can be run against the created API Gateway URL as part of the deployment.
  # We experienced timeouts, and recommend to wait for about 10 seconds before executing them.
  
end
``` 

Shutting down an environment is straight forward. Again an example rake task:

```ruby
task :shutdown, :environment do |t, args|
  
  env = args[:environment]
  
  # remove the stage form API Gateway
  LambdaWrap::ApiGatewayManager.new.shutdown_apigateway(DEFAULT_API_NAME, env)
  
  # remove lambda aliases
  LambdaWrap::LambdaManager.new().remove_alias('func1', env)
  
  # delete DynamoDB table
  LambdaWrap::DynamoDbManager.new().delete_database('myservice-' + env)
  
end
```

## Contributing

We appreciate contributions. Fork the repository and come up with a pull request. Thank you!

We will focus the development of LambdaWrap on lowering the initial costs of setting up a multi-environment supported deployment pipeline for AWS Lambda based services.
