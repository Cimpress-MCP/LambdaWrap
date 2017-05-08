require 'rake'
require 'rake/clean'
require 'rake/testtask'
#require 'lib/lambda_wrap/version'

CLEAN.include('*.gem')

desc 'Builds the gem.'
task build: [:clean, :lint, :unit_test, :integration_test, :create]

desc 'Runs Rubocop'
task :lint do
  if RUBY_VERSION >= '2.0.0'
    cmd = 'rubocop -a -F'
    system(cmd)
  end
end

Rake::TestTask.new do |t|
  t.test_files = FileList['test/unit/test*.rb']
  t.warning = false
  t.verbose = true
  t.name = :unit_test
  t.options = '--pride'
end

Rake::TestTask.new do |t|
  t.test_files = FileList['test/integration/test*.rb']
  t.warning = false
  t.verbose = true
  t.name = :integration_test
  t.options = '--pride'
end

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
