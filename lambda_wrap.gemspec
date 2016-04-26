require_relative 'version'

Gem::Specification.new do |s|
  s.name        = 'lambda_wrap'
  s.version     = VERSION.to_s
  s.platform    = Gem::Platform::RUBY
  s.summary     = "Easy deployment of AWS Lambda functions and dependencies."
  s.description = "This gem wraps the AWS SDK to simplify deployment of AWS Lambda functions backed by API Gateway and DynamoDB."
  s.authors     = ["Markus Thurner", "Dorota Ruta", "Ted Armstrong"]
  s.files       = Dir.glob("{bin,lib}/{**}/{*}", File::FNM_DOTMATCH).select{|f| !(File.basename(f)).match(/^\.+$/)}
  s.license       = 'Apache-2.0'
  s.require_paths = ['lib']
  s.add_runtime_dependency('aws-sdk', '~> 2')
end
