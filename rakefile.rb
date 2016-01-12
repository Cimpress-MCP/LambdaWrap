require 'rake'
require 'rake/clean'
require 'rubygems/package_task'
require_relative 'version'

STDOUT.sync = true
STDERR.sync = true

NAME = 'lambda_wrap'

desc 'Clean'
task :clean do
    Dir.glob('*.gem').each do |f|
        puts "Deleting file #{f}"
        File.delete(f)
    end
end

desc 'Creates the ruby gem'
task :create => :clean do
    puts "Creating gem with version #{VERSION}"
    puts %x[gem build lambda_wrap.gemspec]
end

desc 'Uninstalls the gem'
task :uninstall do
    puts "Uninstalling gem #{NAME}"
    puts %x[gem uninstall #{NAME} --all]
end

desc 'Installs the gem from the local source'
task :installlocal => [:uninstall, :create] do
    gemfile = Dir.glob('*.gem').first()
    puts %x[gem install #{gemfile}]
end

desc 'Installs the ruby gem from rubygems'
task :install do
    gemfile = Dir.glob('*.gem').first()
    puts %x[gem install #{NAME}]
end

desc 'Publishes the ruby gem'
task :publish => :create do
    raise 'Not allowed publishing the gem if version is 0.0.0. Are you on a release branch?' if VERSION.to_s == '0.0.0'
    
    gemfile = Dir.glob('*.gem').first()
    puts "Publishing gem #{gemfile}"
    puts %x[gem push #{gemfile}]
end
