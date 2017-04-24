# encoding: utf-8

$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'lambda_wrap/version'

Gem::Specification.new do |s|
  s.name          = 'lambda_wrap'
  s.version       = LambdaWrap::VERSION
  s.authors       = ['Markus Thurner', 'Dorota Ruta', 'Ted Armstrong']
  s.email         = ['theodorecarmstrong@gmail.com']
  s.homepage      = 'https://github.com/Cimpress-MCP/LambdaWrap'
  s.summary       = 'Easy deployment of AWS Lambda functions and dependencies.'
  s.description   = 'This gem wraps the AWS SDK to simplify deployment of AWS \
                      Lambda functions backed by API Gateway and DynamoDB.'
  s.files         = `git ls-files app lib`.split("\n")
  s.platform      = Gem::Platform::RUBY
  s.require_paths = ['lib']
  s.add_runtime_dependency('aws-sdk', '~> 2')
  s.add_runtime_dependency('rubyzip', '~> 1.2')
  s.license = 'Apache-2.0'
  s.required_ruby_version = '>= 1.9.3'
end
