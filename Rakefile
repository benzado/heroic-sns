require 'rubygems'
require 'bundler/gem_tasks'
require 'rake/testtask'
require 'rdoc/task'

Bundler.setup(:default, :development)

Rake::TestTask.new do |t|
  t.libs << 'test'
end

RDoc::Task.new do |rdoc|
  rdoc.main = "README.md"
  rdoc.rdoc_files.include("README.md", "CHANGELOG.md", "lib")
end

task :demo do
  sh 'rackup -Ilib demo/config.ru'
end

task :default => :test
