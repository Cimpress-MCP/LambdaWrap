require 'rake'
require 'rake/clean'

CLEAN.include('*.gem')

desc 'Builds the gem.'
task build: %i[clean lint unit_test integration_test]

desc 'Runs Rubocop'
task :lint do
  if RUBY_VERSION >= '2.0.0'
    cmd = 'rubocop -a'
    system(cmd)
  end
end

desc 'Unit tests the gem.'
task :unit_test do
  puts 'Running Unit tests...'
  # TODO: Write Unit Tests.
end

desc 'Runs Integration Tests.'
task :integration_test do
  puts 'Running Integration tests...'
  # TODO: Write Integration Tests.
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
