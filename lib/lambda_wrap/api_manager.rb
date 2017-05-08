require 'aws-sdk'
require 'active_support/core_ext/hash'
require_relative 'aws_service'

module LambdaWrap
  # Top level class that manages the Serverless Microservice API deployment.
  class API < AwsService
    attr_reader :lambdas
    attr_reader :dynamo_tables
    attr_reader :api_gateways

    def initialize(options)
      unless options[:lambda_client] && options[:dynamo_client] && options[:api_gateway_client]
        unless options[:access_key_id] ||= ENV['AWS_ACCESS_KEY_ID'] || ENV['ACCESS_KEY']
          raise(ArgumentError, 'Cannot find AWS Access Key ID.')
        end

        unless secret_access_key ||= ENV['AWS_SECRET_ACCESS_KEY'] || ENV['SECRET_KEY']
          raise(ArgumentError, 'Cannot find AWS Secret Key.')
        end

        unless region ||= ENV['AWS_REGION'] || ENV['AMAZON_REGION'] || ENV['AWS_DEFAULT_REGION']
          raise(ArgumentError, 'Cannot find AWS Region.')
        end

        credentials = Aws::Credentials.new(access_key_id, secret_access_key)
      end
      @lambdas = []
      @dynamo_db_tables = []
      @api_gateways = []

      # Should be accessible by other classes in the module.
      @region = region
      @lambda_client = options[:lambda_client] || Aws::Lambda::Client.new(credentials: credentials, region: region)
      @dynamo_client = options[:dynamo_client] || Aws::DynamoDB::Client.new(credentials: credentials, region: region)
      @api_gateway_client = options[:api_gateway_client] ||
                            Aws::APIGateway::Client.new(credentials: credentials, region: region)
    end

    # Add Lambda Object(s) to the API.
    #
    # @param [LambdaWrap::Lambda, Array<LambdaWrap::Lambda>] new_lambda Splat of LambdaWrap Lambda
    #  objects to add to the API. Overloaded as:
    #  add_lambda(lambda1) OR  add_lambda([lambda1, lambda2]) OR add_lambda(lambda1, lambda2)
    def add_lambda(*new_lambda)
      flattened_lambdas = new_lambda.flatten
      flattened_lambdas.each { |lambda| parameter_guard(lambda, LambdaWrap::Lambda, 'LambdaWrap::Lambda') }
      lambdas.concat(flattened_lambdas)
    end

    # Add Dynamo Table Object(s) to the API.
    #
    # @param [LambdaWrap::DynamoTable, Array<LambdaWrap::DynamoTable>] new_table Splat of LambdaWrap DynamoTable
    #  objects to add to the API. Overloaded as:
    #  add_dynamo_table(table1) OR  add_dynamo_table([table1, table2]) OR add_dynamo_table(table1, table2)
    def add_dynamo_table(*new_table)
      flattened_tables = new_table.flatten
      flattened_tables.each { |table| parameter_guard(table, LambdaWrap::DynamoTable, 'LambdaWrap::DynamoTable') }
      dynamo_tables.concat(flattened_tables)
    end

    # Add API Gateway Object(s) to the API.
    #
    # @param [LambdaWrap::ApiGateway, Array<LambdaWrap::ApiGateway>] new_api_gateway Splat of LambdaWrap API Gateway
    #  objects to add to the API. Overloaded as:
    #  add_api_gateway(apig1) OR  add_api_gateway([apig1, apig2]) OR add_api_gateway(apig1, apig2)
    def add_api_gateway(*new_api_gateway)
      flattened_api_gateways = new_api_gateway.flatten
      flattened_api_gateways.each { |apig| parameter_guard(apig, LambdaWrap::ApiGateway, 'LambdaWrap::ApiGateway') }
      api_gateways.concat(flattened_api_gateways)
    end

    # Deploys all services to the specified environment.
    #
    # @param [LambdaWrap::Environment] environment_options the Environment to deploy
    def deploy(environment_options)
      super
      if dynamo_tables.empty? && lambdas.empty? && api_gateways.empty?
        puts 'Nothing to deploy.'
        return
      end

      deployment_start_message = 'Deploying '
      deployment_start_message += "#{dynamo_tables.length} Dynamo Tables, " unless dynamo_tables.empty?
      deployment_start_message += "#{lambdas.length} Lambdas, " unless lambdas.empty?
      deployment_start_message += "#{api_gateways.length} API Gateways " unless api_gateways.empty?
      deployment_start_message += "to Environment: #{environment_options.name}"
      puts deployment_start_message

      total_time_start = Time.now

      services_time_start = total_time_start
      dynamo_tables.each { |table| table.deploy(environment_options) }
      services_time_end = Time.now

      unless dynamo_tables.empty?
        puts "Deploying #{dynamo_tables.length} Table(s) took: \
        #{Time.at(services_time_end - services_time_start).utc.strftime('%H:%M:%S')}"
      end

      services_time_start = Time.now
      lambdas.each { |lambda| lambda.deploy(environment_options) }
      services_time_end = Time.now

      unless lambdas.empty?
        puts "Deploying #{lambdas.length} Lambda(s) took: \
        #{Time.at(services_time_end - services_time_start).utc.strftime('%H:%M:%S')}"
      end

      services_time_start = Time.now
      api_gateways.each { |apig| apig.deploy(environment_options) }
      services_time_end = Time.now

      unless api_gateways.empty?
        puts "Deploying #{api_gateways.length} API Gateway(s) took: \
        #{Time.at(services_time_end - services_time_start).utc.strftime('%H:%M:%S')}"
      end

      total_time_end = Time.now

      puts "Total API Deployment took: \
      #{Time.at(total_time_end - total_time_start).utc.strftime('%H:%M:%S')}"
      puts "Successfully deployed API to #{environment_options.name}"
    end

    # Tearsdown Environment for all services.
    #
    # @param [LambdaWrap::Environment] environment_options the Environment to teardown
    def teardown(environment_options)
      super
      if dynamo_tables.empty? && lambdas.empty? && api_gateways.empty?
        puts 'Nothing to teardown.'
        return
      end

      deployment_start_message = 'Tearing-down '
      deployment_start_message += "#{dynamo_tables.length} Dynamo Tables, " unless dynamo_tables.empty?
      deployment_start_message += "#{lambdas.length} Lambdas, " unless lambdas.empty?
      deployment_start_message += "#{api_gateways.length} API Gateways " unless api_gateways.empty?
      deployment_start_message += " Environment: #{environment_options.name}"
      puts deployment_start_message

      total_time_start = Time.now

      services_time_start = total_time_start
      dynamo_tables.each { |table| table.teardown(environment_options) }
      services_time_end = Time.now

      unless dynamo_tables.empty?
        puts "Tearing-down #{dynamo_tables.length} Table(s) took: \
        #{Time.at(services_time_end - services_time_start).utc.strftime('%H:%M:%S')}"
      end

      services_time_start = Time.now
      lambdas.each { |lambda| lambda.teardown(environment_options) }
      services_time_end = Time.now

      unless lambdas.empty?
        puts "Tearing-down #{lambdas.length} Lambda(s) took: \
        #{Time.at(services_time_end - services_time_start).utc.strftime('%H:%M:%S')}"
      end

      services_time_start = Time.now
      api_gateways.each { |apig| apig.teardown(environment_options) }
      services_time_end = Time.now

      unless api_gateways.empty?
        puts "Tearing-down #{api_gateways.length} API Gateway(s) took: \
        #{Time.at(services_time_end - services_time_start).utc.strftime('%H:%M:%S')}"
      end

      total_time_end = Time.now

      puts "Total API Tear-down took: \
      #{Time.at(total_time_end - total_time_start).utc.strftime('%H:%M:%S')}"
      puts "Successful Teardown API to #{environment_options.name}"
    end

    # Deletes all services from the cloud.
    def delete
      if dynamo_tables.empty? && lambdas.empty? && api_gateways.empty?
        puts 'Nothing to Deleting.'
        return
      end

      deployment_start_message = 'Deleting '
      deployment_start_message += "#{dynamo_tables.length} Dynamo Tables, " unless dynamo_tables.empty?
      deployment_start_message += "#{lambdas.length} Lambdas, " unless lambdas.empty?
      deployment_start_message += "#{api_gateways.length} API Gateways " unless api_gateways.empty?
      deployment_start_message += " Environment: #{environment_options.name}"
      puts deployment_start_message

      total_time_start = Time.now

      services_time_start = total_time_start
      dynamo_tables.each { |table| table.delete(environment_options) }
      services_time_end = Time.now

      unless dynamo_tables.empty?
        puts "Deleting #{dynamo_tables.length} Table(s) took: \
        #{Time.at(services_time_end - services_time_start).utc.strftime('%H:%M:%S')}"
      end

      services_time_start = Time.now
      lambdas.each { |lambda| lambda.delete(environment_options) }
      services_time_end = Time.now

      unless lambdas.empty?
        puts "Deleting #{lambdas.length} Lambda(s) took: \
        #{Time.at(services_time_end - services_time_start).utc.strftime('%H:%M:%S')}"
      end

      services_time_start = Time.now
      api_gateways.each { |apig| apig.delete(environment_options) }
      services_time_end = Time.now

      unless api_gateways.empty?
        puts "Deleting #{api_gateways.length} API Gateway(s) took: \
        #{Time.at(services_time_end - services_time_start).utc.strftime('%H:%M:%S')}"
      end

      total_time_end = Time.now

      puts "Total API Deletion took: \
      #{Time.at(total_time_end - total_time_start).utc.strftime('%H:%M:%S')}"
      puts 'Successful Deletion of API'
    end

    private

    def parameter_guard(parameter, type, type_name)
      return if parameter.is_a(type)
      raise ArgumentError, "Must pass a #{type_name} to the API Manager. Got: #{parameter}"
    end
  end
end
