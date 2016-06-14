require 'rake'
require 'rake/clean'
require 'bundler/setup'
require 'rubygems/package_task'
require_relative 'version'

STDOUT.sync = true
STDERR.sync = true

NAME = 'lambda_wrap'.freeze

desc 'Clean'
task :clean do
  Dir.glob('*.gem').each do |f|
    puts "Deleting file #{f}"
    File.delete(f)
  end
end

desc 'Creates the ruby gem'
task create: [:clean] do
  puts "Creating gem with version #{VERSION}"
  puts `gem build lambda_wrap.gemspec`
end

task test: :rubocop

task :rubocop do
  `rubocop`
end

desc 'Uninstalls the gem'
task :uninstall do
  puts "Uninstalling gem #{NAME}"
  puts `gem uninstall #{NAME} --all`
end

desc 'Installs the gem from the local source'
task installlocal: [:uninstall, :create, :test] do
  gemfile = Dir.glob('*.gem').first
  puts `gem install #{gemfile}`
end

desc 'Installs the ruby gem from rubygems'
task :install do
  puts `gem install #{NAME}`
end

desc 'Publishes the ruby gem'
task publish: [:create, :test] do
  if VERSION.to_s == '0.0.0'
    raise 'Not allowed publishing the gem if version is 0.0.0.'\
      'Are you on a release branch?'
  end

  gemfile = Dir.glob('*.gem').first
  puts "Publishing gem #{gemfile}"
  puts `gem push #{gemfile}`
end
