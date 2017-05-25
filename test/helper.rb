require 'simplecov'
SimpleCov.start do
  coverage_dir 'reports/coverage'
  add_filter 'test'
end

require 'active_support/all'
require 'minitest/autorun'
require 'minitest/reporters'
Minitest::Reporters.use! [
  Minitest::Reporters::HtmlReporter.new(reports_dir: 'reports')
]

require 'aws-sdk'
require 'lambda_wrap'

def silence_output
  # Store the original stdout in order to restore later
  @original_stdout = $stdout

  Dir.mkdir(File.join(Dir.getwd, 'reports')) unless Dir.exist?('./reports')

  # Redirect stdout
  $stdout = File.new('reports/UnitTestOutput.txt', 'w')
end

# Replace stdout so anything else is output correctly
def enable_output
  $stdout = @original_stdout
  @original_stdout = nil
end
