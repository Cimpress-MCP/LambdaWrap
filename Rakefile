require 'rake'
require 'rake/clean'
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'lib'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = false
end

task default: test

desc 'Clean'
task :clean do
  Dir.glob('*.gem').each do |f|
    puts "Deleting file #{f}"
    File.delete(f)
  end
end

desc 'Uninstalls the gem'
task :uninstall do
  puts "Uninstalling gem #{NAME}"
  puts `gem uninstall #{NAME} --all`
end
