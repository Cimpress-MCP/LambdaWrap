# LambdaWrap

A ruby library to simplify deployment of a serverless web service based on AWS Lambda, AWS API Gateway and AWS DynamoDB.

LambdaWrap is a very simple way to manage and automate deployment of AWS Lambda functions and related functionality. It is targeted to simple use cases and focuses only on deployment automation. Its primary goal is to support developers who want to be able to spend less than 1h on infrastructure and focus on the actual value delivered by their web service.

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
7. A versioned S3 bucket to host the Lambda package.

### Using LambdaWrap

See the documentation or source code for detailed usage. But the following lines provide an example how a rakefile can look like:

```ruby
task :deploy, :environment do |t, args|

  env = args[:environment] #e.g. 'prod'
  api_name = 'LambdaWrapService'


  # DynamoDB publishing Functions
  attributes = [{ attribute_name: "Key", attribute_type: "S" }]
  keyschema = [{ attribute_name: "Key", key_type: "HASH" }]
  LambdaWrap::DynamoDbManager.new().publish_database('myservice-' + env, attributes, keyschema, 1, 1)



  #Lambda Functions
  ## Packaging
  node_modules = Array.new
  JSON.parse(File.read('path/to/package.json'))['dependencies'].each do |key, value|
      node_modules << key
  end
  javascript_file_names = Dir.glob(File.join('src/directory', '*.js'))
  LambdaWrap::LambdaManager.new().package('package_directory', 'path/to/package.zip', javascript_file_names, node_modules)


  ## Publishing package to S3
  s3_version_id = LambdaWrap::LambdaManager.new().publish_lambda_to_s3('path/to/package.zip', 's3_bucket_name', 's3_key/lambda/service.zip')


  ## Deploying S3 Package to Lambda
  ### the description, subnet_ids, and security_groups are optional.
  lambda_functions = [
    {
      "name" => "Function1",
      "handler" => "func1.handler",
      "description" => "Function1 Description"
    },
    {
      "name" => "Function2",
      "handler" => "func2.handler",
      "description" => "Function2 Description"
    }
  ]

  subnet_ids = [
    'subnet-12345678',
    'subnet-87654321',
    'subnet-10203040'
  ]

  security_groups = [
    'sg-12345678'
  ]

  lambda_role_arn = 'arn:aws:iam::0123456789012/role/foobar'

  lambda_functions.each do |f|
    lambdaMgr = LambdWrap::LambdaManager.new()
    func_version = lambdaMgr.deploy_lambda(
      's3_bucket_name',
      's3_key/lambda/service.zip',
      s3_version_id,
      f['name'],
      f['handler'],
      lambda_role_arn,
      f['description'],
      subnet_ids,
      security_groups)
    lambdaMgr.create_alias(f['name'], func_version, env)
  end


  # Configure API Gateway
  ag_mgr = LambdaWrap::ApiGatewayManager.new()
  ag_mgr.download_apigateway_importer('s3_bucket_name', 's3/key/to/aws-apigateway-importer-1.0.3-SNAPSHOT-jar-with-dependencies.jar') #required step
  uri = ag_mgr.setup_apigateway(api_name, env, 'path/to/swagger_doc.json')

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
