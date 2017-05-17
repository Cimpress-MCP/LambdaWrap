require './test/helper.rb'

class TestApiGateway < Minitest::Test
  describe LambdaWrap::ApiGateway do
    def setup
      silence_output
    end

    def teardown
      enable_output
    end

    class FileOpenDouble
      def read
        'BLOB DATA'
      end
    end

    let(:environment_valid) do
      LambdaWrap::Environment.new('UnitTestingValid', { variable: 'valueValid' },
                                  'My UnitTesting EnvironmentValid')
    end

    let(:apig_valid) do
      LambdaWrap::ApiGateway.new(path_to_swagger_file: './test/data/swagger_valid_1.yaml')
    end

    describe ' when constructing the API Gateway ' do
      it ' should create successfully with all valid values given.' do
        apig_under_test = LambdaWrap::ApiGateway.new(path_to_swagger_file: './test/data/swagger_valid_1.yaml',
                                                     import_mode: 'merge')
        apig_under_test.must_be_instance_of(LambdaWrap::ApiGateway)
      end
      it ' should throw an error if the swagger file doesnt exist.' do
        proc {
          LambdaWrap::ApiGateway.new(
            path_to_swagger_file: '.non/existent/file.yaml', import_mode: 'merge'
          )
        }.must_raise(ArgumentError).to_s
          .must_match(/File does not exist/)
      end
    end

    describe ' when deploying the API Gateway ' do
      it ' should create an API Gateway object successfully. ' do
        apig_client = Aws::APIGateway::Client.new(
          region: 'eu-west-1',
          stub_responses: {
            get_rest_apis: [
              {
                position: 'position',
                items: [
                  { id: '1', name: 'api1', description: 'api1desc' },
                  { id: '2', name: 'api2', description: 'api2desc' },
                  { id: '3', name: 'api3', description: 'api3desc' }
                ]
              },
              {
                items: [
                  { id: '4', name: 'api4', description: 'api4desc' }
                ]
              }
            ],
            put_rest_api: 'Error',
            import_rest_api: {
              id: '5',
              name: 'validapi',
              created_date: Time.now
            },
            create_deployment: {
              id: 'deployment1',
              description: 'deployment1desc',
              created_date: Time.now
            }
          }
        )
        expected_service_ui = 'https://5.execute-api.eu-west-1.amazonaws.com/UnitTestingValid/'
        apig_valid.deploy(environment_valid, apig_client, 'eu-west-1').must_equal(expected_service_ui)
      end
      it ' should update an API Gateway object successfully. ' do
        apig_client = Aws::APIGateway::Client.new(
          region: 'eu-west-1',
          stub_responses: {
            get_rest_apis: [
              {
                position: 'position',
                items: [
                  { id: '1', name: 'api1', description: 'api1desc' },
                  { id: '2', name: 'api2', description: 'api2desc' },
                  { id: '3', name: 'api3', description: 'api3desc' }
                ]
              },
              {
                items: [
                  { id: '4', name: 'api4', description: 'api4desc' },
                  { id: '5', name: 'Swagger Petstore', description: 'ValidSwagger' }
                ]
              }
            ],
            put_rest_api: {
              id: '5',
              name: 'Swagger Petstore',
              description: 'ValidSwagger',
              created_date: Time.now
            },
            import_rest_api: 'Error',
            create_deployment: {
              id: 'deployment1',
              description: 'deployment1desc',
              created_date: Time.now
            }
          }
        )
        expected_service_ui = 'https://5.execute-api.eu-west-1.amazonaws.com/UnitTestingValid/'
        apig_valid.deploy(environment_valid, apig_client, 'eu-west-1').must_equal(expected_service_ui)
      end
      it ' should fail if AWS cannot import the Swagger File. ' do
        apig_client = Aws::APIGateway::Client.new(
          region: 'eu-west-1',
          stub_responses: {
            get_rest_apis: [
              {
                position: 'position',
                items: [
                  { id: '1', name: 'api1', description: 'api1desc' },
                  { id: '2', name: 'api2', description: 'api2desc' },
                  { id: '3', name: 'api3', description: 'api3desc' }
                ]
              },
              {
                items: [
                  { id: '4', name: 'api4', description: 'api4desc' },
                  { id: '5', name: 'Swagger Petstore', description: 'ValidSwagger' }
                ]
              }
            ],
            put_rest_api: {
              id: nil
            },
            import_rest_api: 'Error',
            create_deployment: {
              id: 'deployment1',
              description: 'deployment1desc',
              created_date: Time.now
            }
          }
        )
        proc { apig_valid.deploy(environment_valid, apig_client, 'eu-west-1') }.must_raise(RuntimeError)
      end
    end

    describe ' when tearing-down the API Gateway ' do
      it ' should tear-down successfully with valid stage to delete. ' do
        apig_client = Aws::APIGateway::Client.new(
          region: 'eu-west-1',
          stub_responses: {
            get_rest_apis: [
              {
                position: 'position',
                items: [
                  { id: '1', name: 'api1', description: 'api1desc' },
                  { id: '2', name: 'api2', description: 'api2desc' },
                  { id: '3', name: 'api3', description: 'api3desc' }
                ]
              },
              {
                items: [
                  { id: '4', name: 'api4', description: 'api4desc' },
                  { id: '5', name: 'Swagger Petstore', description: 'validdesc' }
                ]
              }
            ],
            delete_stage: {}
          }
        )
        apig_valid.teardown(environment_valid, apig_client, 'eu-west-1').must_equal(true)
      end
      it ' should tear-down successfully if stage doesnt exist. ' do
        apig_client = Aws::APIGateway::Client.new(
          region: 'eu-west-1',
          stub_responses: {
            get_rest_apis: [
              {
                position: 'position',
                items: [
                  { id: '1', name: 'api1', description: 'api1desc' },
                  { id: '2', name: 'api2', description: 'api2desc' },
                  { id: '3', name: 'api3', description: 'api3desc' }
                ]
              },
              {
                items: [
                  { id: '4', name: 'api4', description: 'api4desc' },
                  { id: '5', name: 'Swagger Petstore', description: 'validdesc' }
                ]
              }
            ],
            delete_stage: 'NotFoundException'
          }
        )
        apig_valid.teardown(environment_valid, apig_client, 'eu-west-1').must_equal(true)
      end
      it ' should tear-down successfully if the API Gateway Object doesnt exist. ' do
        apig_client = Aws::APIGateway::Client.new(
          region: 'eu-west-1',
          stub_responses: {
            get_rest_apis: [
              {
                position: 'position',
                items: [
                  { id: '1', name: 'api1', description: 'api1desc' },
                  { id: '2', name: 'api2', description: 'api2desc' },
                  { id: '3', name: 'api3', description: 'api3desc' }
                ]
              },
              {
                items: [
                  { id: '4', name: 'api4', description: 'api4desc' }
                ]
              }
            ]
          }
        )
        apig_valid.teardown(environment_valid, apig_client, 'eu-west-1').must_equal(true)
      end
    end
    describe ' when deleting the API Gateway ' do
      it ' should delete successfully with valid API Object and stages to delete. ' do
        apig_client = Aws::APIGateway::Client.new(
          region: 'eu-west-1',
          stub_responses: {
            get_rest_apis: [
              {
                position: 'position',
                items: [
                  { id: '1', name: 'api1', description: 'api1desc' },
                  { id: '2', name: 'api2', description: 'api2desc' },
                  { id: '3', name: 'api3', description: 'api3desc' }
                ]
              },
              {
                items: [
                  { id: '4', name: 'api4', description: 'api4desc' },
                  { id: '5', name: 'Swagger Petstore', description: 'validdesc' }
                ]
              }
            ],
            delete_rest_api: {}
          }
        )
        apig_valid.delete(apig_client, 'eu-west-1').must_equal(true)
      end
      it ' should delete successfully with no API Object in the cloud. ' do
        apig_client = Aws::APIGateway::Client.new(
          region: 'eu-west-1',
          stub_responses: {
            get_rest_apis: [
              {
                position: 'position',
                items: [
                  { id: '1', name: 'api1', description: 'api1desc' },
                  { id: '2', name: 'api2', description: 'api2desc' },
                  { id: '3', name: 'api3', description: 'api3desc' }
                ]
              },
              {
                items: [
                  { id: '4', name: 'api4', description: 'api4desc' }
                ]
              }
            ],
            delete_rest_api: 'RuntimeError'
          }
        )
        apig_valid.delete(apig_client, 'eu-west-1').must_equal(true)
      end
    end
  end
end
