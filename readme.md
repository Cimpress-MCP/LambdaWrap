# LambdaWrap

[![BuildStatus](https://travis-ci.org/Cimpress-MCP/LambdaWrap.svg?branch=master)](https://travis-ci.org/Cimpress-MCP/LambdaWrap) [![GemVersion](https://badge.fury.io/rb/lambda_wrap.svg)](https://badge.fury.io/rb/lambda_wrap)
[![Code Climate](https://codeclimate.com/github/Cimpress-MCP/LambdaWrap/badges/gpa.svg)](https://codeclimate.com/github/Cimpress-MCP/LambdaWrap)
[![Test Coverage](https://codeclimate.com/github/Cimpress-MCP/LambdaWrap/badges/coverage.svg)](https://codeclimate.com/github/Cimpress-MCP/LambdaWrap/coverage)

A ruby library to simplify deployment of a Serverless RESTful API, coordinating the AWS Services: AWS Lambda, API Gateway and DynamoDB, agnostic of the Runtime engine and Package structure.


* [**Home**](https://github.com/Cimpress-MCP/LambdaWrap)
* [**YARD Docs**](http://www.rubydoc.info/github/Cimpress-MCP/LambdaWrap)
* [**Bugs**](https://github.com/Cimpress-MCP/LambdaWrap/issues)


## Description
LambdaWrap is a very simple way to manage and automate deployment of AWS Lambda functions and related functionality. It is targeted to simple use cases and focuses only on deployment automation. Its primary goal is to support developers who want to be able to spend less than 1h on infrastructure and focus on the actual value delivered by their web service.

Technically, it uses the [AWS SDK](https://aws.amazon.com/sdk-for-ruby/) directly and avoids complexities such as [AWS Cloudformation](https://aws.amazon.com/cloudformation/). Due to its focus on simplifying deployment, it has no built in support to run the functions locally, such as [serverless](https://github.com/serverless/serverless) has.

LambdaWrap utilizes the notion of 'Environments' for the partitioning of data and behavior by leveraging the notion of Lambda Aliases, and API Gateway Stages. For example, when the user deploys to a Production environment, the Lambda Alias of 'Production' and an API Gateway stage of 'Production' are created. The Production stage of API Gateway is intended to invoke the Production alias of the Lambda.

The purpose of this deployment tool is to front-load configuration in a declarative style. Configuration of your services should be stored in a version controlled YAML file.
Similarly, your API and integrations must be defined in an [Open API Specificaiton (fka Swagger)](http://swagger.io/) file. Please consult the [AWS API Gateway swagger extensions](http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-swagger-extensions.html) for further configuration.

Cursory knowledge of AWS Services is required: [Lambda](https://aws.amazon.com/lambda/), [DynamoDB](https://aws.amazon.com/dynamodb/), [API Gateway](https://aws.amazon.com/api-gateway).


**Note on Function Versioning**

Lambda Function Version Numbers are a strictly increasing integer function. Reverting function versions is not supported with LambdaWrap, and should not be considered in your stack. If the Behavior of your application needs to reverted, I recommend reverting the change in version control, and making a new deployment to the same environment.

Similarly, aliases should not be assigned to any function version lower than its current setting.

The `LambdaWrap::Lambda` has an option to delete function versions from the Lambda as soon as they are not pointed at by an alias. This option is defaulted to true.

## Installation

_Recommended:_ Use Bundler for all your ruby projects!

Add the lambda_wrap gem to your Gemfile:
```ruby
gem 'lambda_wrap'
```

Or you can install it globally using RubyGems:
`gem install lambda_wrap`

## Using LambdaWrap
LambdaWrap relies upon a lot of initial configuration, with minimal Deployment configuration. It's highly recommended to store your configuration in a seperate file that is version controlled and can be read in from a Rakefile, and passed to LambdaWrap.

Create a `LambdaWrap::API` class, then add the services you need to the API Class. You can then deploy and teardown your entire Stack with a single call to the `LambdaWrap::API` class.

### Construct the API
Pass in your AWS credentials and Region to the `LambdaWrap::API` class. This class will also read the Environment Variables that the SDK also looks for to extract credentials.

```ruby
my_api = LambdaWrap::API.new(
  access_key_id: 'YOUR_ACCESS_KEY_ID',
  secret_access_key: 'YOUR_SECRET_ACCESS_KEY',
  region: 'eu-west-1'
)
```

### Construct The Lambdas
Each Lambda has a variety of variables that need to be configured for each lambda. Some default values are supported. For Note: Since this is a deployment tool, the responsibility of packaging your application should be handled elsewhere.
* [Lambda Programming Model](http://docs.aws.amazon.com/lambda/latest/dg/lambda-app.html)
* [VPC Support](http://docs.aws.amazon.com/lambda/latest/dg/vpc.html)
* [Function Versioning & Aliases](http://docs.aws.amazon.com/lambda/latest/dg/versioning-aliases.html)

```ruby
lambda_1 = LambdaWrap::Lambda.new(
  lambda_name: 'Lambda1',
  handler: 'Lambda1Nodejs.handler',
  role_arn: 'arn:aws:iam::012345678901:role/LambdaExecutionIAMRole',
  path_to_zip_file: File.join(File.dirname(__FILE__), 'package/Lambda1DeploymentPackage.zip'),
  runtime: 'nodejs6.10',
  description: 'This NodeJS Lambda does ....', # optional
  timeout: 30, # in Seconds. Defaults to 30
  memory_size: 128, # in MB, Increments of 64. Defaults to 128
  # If a VPC is necessary, specify the subnets and security groups.
  # Optional parameters, but if one is supplied, so must the other.
  subnet_ids: %w[SubnetA, SubnetB, SubnetC],
  security_group_ids: %w[SecurityGroupId],
  delete_unreferenced_versions: true # Optional. Defaults to true.
)

lambda_2 = LambdaWrap::Lambda.new(
  lambda_name: 'Lambda2',
  handler: 'LambdaAssembly::CsProj.CsClass::FunctionName',
  role_arn: 'arn:aws:iam::012345678901:role/LambdaExecutionIAMRole',
  path_to_zip_file: File.join(File.dirname(__FILE__), 'package/Lambda2DeploymentPackage.zip'),
  runtime: 'dotnetcore1.0',
  description: 'This .NET Core Lambda does ....',
  timeout: 300, # Current Maximum Value
  memory_size: 1536, # Current Maximum Value
  subnet_ids: %w[SubnetA, SubnetB, SubnetC],
  security_group_ids: %w[SecurityGroupId],
  delete_unreferenced_versions: true
)

lambda_3 = LambdaWrap::Lambda.new(
  lambda_name: 'Lambda3',
  handler: 'Lambda3Python.handler',
  role_arn: 'arn:aws:iam::012345678901:role/LambdaExecutionIAMRole',
  path_to_zip_file: File.join(File.dirnmae(__FILE__), 'package/Lambda3DeploymentPackage.zip'),
  runtime: 'python3.6',
  description: 'This Python Lambda does ....',
  timeout: 45,
  memory_size: 256,
  subnet_ids: %w[SubnetA, SubnetB, SubnetC],
  security_group_ids: %w[SecurityGroupId],
  delete_unreferenced_versions: true
)

# ......

lambda_n = LambdaWrap::Lambda.new(
  lambda_name: 'LambdaN',
  handler: 'PackageName.ClassName::Handler',
  role_arn: 'arn:aws:iam::012345678901:role/LambdaExecutionIAMRole',
  path_to_zip_file: File.join(File.dirnmae(__FILE__), 'package/LambdaNDeploymentPackage.zip'),
  runtime: 'java8',
  description: 'This Java Lambda does ....',
  timeout: 25,
  memory_size: 512,
  delete_unreferenced_versions: true
)
```

### Construct the Dynamo Tables
There are enough default values supported to get a full dynamo table up and running.
DynamoDB does not currently have an inherent notion of partitioning in the same way that Lambda has Aliases and API Gateway has stages. Some users have one 'Master' table which handles the data from all environments and adds an Environment or Tenant field.

However, if you would like a table per environment, you can handle the Table Naming yourself, or you can set the `LambdaWrap::DynamoTable` option to append the Environment name to the table name upon deployment.

Please familiarize yourself with the DynamoDB Developer Guide before configuring your own table.


* [DynamoDB Developer Guide](http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.html)

```ruby
# A deployment of this table to 'production' will result in the creation of
# a 'Issues-production' table because the 'append_environment_on_deploy' is set.
table_1 = LambdaWrap::DynamoTable.new(
  table_name: 'Issues', attribute_definitions:
    [
      { attribute_name: 'IssueId', attribute_type: 'S' },
      { attribute_name: 'Title', attribute_type: 'S' },
      { attribute_name: 'CreateDate', attribute_type: 'S' },
      { attribute_name: 'DueDate', attribute_type: 'S' }
    ],
  key_schema: [{ attribute_name: 'IssueId', key_type: 'HASH' },
               { attribute_name: 'Title', key_type: 'RANGE' }],
  read_capacity_units: 8, write_capacity_units: 4,
  global_secondary_indexes:
    [
      {
        index_name: 'CreateDateIndex',
        provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
        key_schema: [{ attribute_name: 'CreateDate', key_type: 'HASH' },
                     { attribute_name: 'IssueId', key_type: 'RANGE' }],
        projection: {
          projection_type: 'INCLUDE',
          non_key_attributes: %w[Description Status]
        }
      },
      {
        index_name: 'TitleIndex',
        provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
        key_schema: [{ attribute_name: 'Title', key_type: 'HASH' },
                     { attribute_name: 'IssueId', key_type: 'RANGE' }],
        projection: {
          projection_type: 'KEYS_ONLY'
        }
      },
      {
        index_name: 'DueDateIndex',
        provisioned_throughput: { read_capacity_units: 4, write_capacity_units: 2 },
        key_schema: [{ attribute_name: 'DueDate', key_type: 'HASH' }],
        projection: {
          projection_type: 'ALL'
        }
      }
    ],
  local_secondary_indexes:
    [
      { index_name: 'LocalIndex', key_schema: [{ attribute_name: 'Title', key_type: 'HASH' }],
        projection: { projection_type: 'ALL' } }
    ],
  append_environment_on_deploy: true
)
```

### Construct the API Gateways
The configuration for each API Gateway object should be implemented in the OAPISpec/Swagger file. API Gateway only supports Swaggerv2.0 currently.
LambdaWrap does not validate the Swagger File due to LambdaWrap's support of Ruby Version 1.9.3.

* [API Gateway Developer guide](http://docs.aws.amazon.com/apigateway/latest/developerguide/welcome.html)
* [OpenAPI Specification (fka Swagger)](http://swagger.io/specification/)
* [API Gateway Extensions to swagger](http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-swagger-extensions.html)

```ruby
api_gateway_1 = LambdaWrap::ApiGateway.new(
  swagger_file_path: 'my/api/spec/Swagger1.yaml',
  import_mode: 'overwrite' # How API Gateway imports swagger files. Accepts 'overwrite' and 'merge'
)

api_gateway_2 = LambdaWrap::ApiGateway.new(
  swagger_file_path: 'my/api/spec/Swagger2.yaml',
  import_mode: 'merge'
)
```

### Construct the Environments
Each deployment and teardown task must be passed a `LambdaWrap::Environment`.
Upon deployment, the Hash of variables will be created as Stage Variables in the API Gateway stage. Will automatically add an 'environment' key to the variables.

```ruby
production = LambdaWrap::Environment.new(
  name: 'production',
  variables:
    {
      database_connection_string: 'production;database',
      foo: 'bar'
    },
  description: 'Live! Dont touch!'
)

staging = LambdaWrap::Environment.new(
  name: 'staging',
  variables:
    {
      database_connection_string: 'staging;database',
      foo: 'baz'
    },
  description: 'You can mess with me. '
)
```

### Populating the API
```ruby
my_api.add_lambda(lambda_1, lambda_2, lambda_3, .... , lambda_n)
my_api.add_dynamo_table(table_1, ...)
my_api.add_api_gateway([api_gateway_1, api_gateway_2])
```

### Deploying the API to an environment
Using the variables defined from above.
```ruby
my_api.deploy(production)
```

### Tearing-down the API From an environment
```ruby
my_api.teardown(production)
```

### Deleting all live environments and AWS objects for the API
```ruby
my_api.delete
```

## Examples
### Configuration File
```
lambdas:
  - lambda_name: 'Lambda1'
    handler: 'Lambda1Nodejs.handler'
    role_arn: 'arn:aws:iam::012345678901:role/LambdaExecutionIAMRole'
    path_to_zip_file: 'package/Lambda1DeploymentPackage.zip'
    runtime: 'nodejs6.10'
    description: 'This NodeJS Lambda does ....'
    timeout: 30
    memory_size: 128
    subnet_ids:
      - 'SubnetA'
      - 'SubnetB'
      - 'SubnetC'
    security_group_ids:
      - 'SecurityGroupId'
    delete_unreferenced_versions: true

  - lambda_name: 'Lambda2'
    handler: 'LambdaAssembly::CsProj.CsClass::FunctionName'
    role_arn: 'arn:aws:iam::012345678901:role/LambdaExecutionIAMRole'
    path_to_zip_file: 'package/Lambda2DeploymentPackage.zip'
    runtime: 'dotnetcore1.0'
    description: 'This .NET Core Lambda does ....'
    timeout: 300
    memory_size: 1536
    subnet_ids:
      - 'SubnetA'
      - 'SubnetB'
      - 'SubnetC'
    security_group_ids:
      - 'SecurityGroupId'
    delete_unreferenced_versions: true

dynamo_tables:
  - table_name: 'Issues'
    attribute_definitions:
      - attribute_name: 'IssueId'
        attribute_type: 'S'
      - attribute_name: 'Title'
        attribute_type: 'S'
      - attribute_name: 'CreateDate'
        attribute_type: 'S'
      - attribute_name: 'DueDate'
        attribute_type: 'S'
    key_schema:
      - attribute_name: 'IssueId'
        key_type: 'HASH'
      - attribute_name: 'Title'
        key_type: 'RANGE'
    read_capacity_units: 8
    write_capacity_units: 4
    global_secondary_indexes:
      - index_name: 'CreateDateIndex'
        provisioned_throughput:
          read_capacity_units: 4
          write_capacity_units: 2
        key_schema:
          - attribute_name: 'CreateDate'
            key_type: 'HASH'
          - attribute_name: 'IssueId'
            key_type: 'RANGE'
        projection:
          projection_type: 'INCLUDE'
          non_key_attributes:
            - 'Description'
            - 'Status'

      - index_name: 'TitleIndex'
        provisioned_throughput:
          read_capacity_units: 4
          write_capacity_units: 2
        key_schema:
          - attribute_name: 'Title'
            key_type: 'HASH'
          - attribute_name: 'IssueId'
            key_type: 'RANGE'
        projection:
          projection_type: 'KEYS_ONLY'

      - index_name: 'DueDateIndex'
        provisioned_throughput:
          read_capacity_units: 4
          write_capacity_units: 2
        key_schema:
          - attribute_name: 'DueDate'
            key_type: 'HASH'
        projection:
          projection_type: 'ALL'

    local_secondary_indexes:
      - index_name: 'LocalIndex'
        key_schema:
          - attribute_name: 'Title'
            key_type: 'HASH'
            projection:
              projection_type: 'ALL'

    append_environment_on_deploy: true

api_gateways:
  - swagger_file_path: 'my/api/spec/Swagger1.yaml'
    import_mode: 'overwrite'
  - swagger_file_path: 'my/api/spec/Swagger2.yaml'
    import_mode: 'merge'

environments:
  production:
    name: 'production'
    variables:
      database_connection_string: 'production;database'
      foo: 'bar'
    description: 'Live! Dont touch!'

  staging:
    name: 'staging'
    variables:
      database_connection_string: 'staging;database'
      foo: 'baz'
    description: 'You can mess with me. '
```

### Rakefile
```ruby
require 'active_support/core_ext/hash' # for Hash#deep_symbolize_keys

desc 'Parses configuration and constructs LambdaWrap Objects.'
task :parse_configuration do
  CONFIGURATION = YAML::load_file(File.join(CONFIG_DIR, 'config.yaml')).deep_symbolize_keys
  API = LambdaWrap::API.new('ACCESS_ID', 'SECRET_KEY', 'AWS_REGION')
  CONFIGURATION[:lambdas].each do |lambda_config|
    API.add_lambda(LambdaWrap::Lambda.new(lambda_config)
  end
  CONFIGURATION[:dynamo_tables].each do |dynamo_table_config|
    API.add_dynamo_table(LambdaWrap::DynamoTable.new(dynamo_table_config))
  end
  CONFIGURATION[:api_gateways].each do |api_gateway_config|
    API.add_api_gateway(LambdaWrap::ApiGateway.new(api_gateway_config))
  end
  ENVIRONMENTS = {}
  CONFIGURATION[:environments].each do |environment|
    ENVIRONMENTS[environment] = LambdaWrap::Environment.new(environment[:config])
  end
end

desc 'Deploys the API to Production.'
task :deploy_to_production do
  API.deploy(ENVIRONMENTS[:production])
end
```

## Contributing

We appreciate contributions.
If you would like to contribute, please fork the repository, branch off master into a feature branch, then open a pull request.
Thanks in advance!

We will focus the development of LambdaWrap on lowering the initial costs of setting up a multi-environment supported deployment pipeline for AWS Lambda based services.
