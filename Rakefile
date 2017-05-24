require 'rake'
require 'rake/clean'
require 'rake/testtask'
require 'yard'
require './lib/lambda_wrap/version'

ROOT = File.dirname(__FILE__)

CLEAN.include('*.gem')
CLEAN.include(File.join(ROOT, 'reports'))
CLEAN.include(File.join(ROOT, 'doc'))

desc 'Builds the gem.'
task build: [:clean, :lint, :unit_test, :integration_test, :create]

task commit_job: [:clean, :lint, :unit_test, :integration_test, :cc_test_reporter, :yard, :create]

desc 'Runs Rubocop'
task :lint do
  if RUBY_VERSION >= '2.0.0'
    cmd = 'rubocop -a -F'
    system(cmd)
  end
end

Rake::TestTask.new(:unit_test) do |t|
  t.test_files = FileList['test/unit/test*.rb']
  t.warning = false
  t.verbose = true
  t.options = '--pride'
end

Rake::TestTask.new(:integration_test) do |t|
  t.test_files = FileList['test/integration/test*.rb']
  t.warning = false
  t.verbose = true
  t.options = '--pride'
end

YARD::Rake::YardocTask.new do |t|
  t.files = ['lib/**/*.rb']
end

task :cc_test_reporter => [:unit_test] do
  ENV['CODECLIMATE_REPO_TOKEN'] = 'c6ffcbf1b751dcca3f601f90e64149b0d9e475d73f1eb895823334870bc27a9d'
  cmd = 'bundle exec codeclimate-test-reporter reports/coverage/.resultset.json'
  raise 'Could not run CodeClimate Test Reporter.' if !system(cmd)
end

task :yard => [:clean]

desc 'Creates the ruby gem'
task create: [:clean] do
  puts "Creating gem: #{LambdaWrap::VERSION}"
  puts `gem build lambda_wrap.gemspec`
end

desc 'Uninstalls the gem'
task :uninstall do
  puts "Uninstalling gem #{NAME}"
  puts `gem uninstall #{NAME} --all`
end

desc 'Bumps and pushes new minor version.'
task :bump_minor do
  puts 'Bumping minor.'
  cmd = 'gem bump --version minor --tag --push'
  raise 'Error bumping minor version!' unless system(cmd)
end

desc 'Bumps and pushes new major version.'
task :bump_major do
  puts 'Bumping major.'
  cmd = 'gem bump --version major --tag --push'
  raise 'Error bumping major version!' unless system(cmd)
end

desc 'Bumps and pushes new patch version.'
task :bump_patch do
  puts 'Bumping patch.'
  cmd = 'gem bump --version patch --tag --push'
  raise 'Error bumping patch version!' unless system(cmd)
end
