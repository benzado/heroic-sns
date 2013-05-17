require 'rubygems'
require 'bundler/gem_tasks'
require 'rake/testtask'

Bundler.setup(:default, :development)

Rake::TestTask.new do |t|
  t.libs << 'test'
end

task :demo do
  sh 'rackup -Ilib demo/config.ru'
end

task :default => :test
