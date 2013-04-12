require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'test'
end

task :demo do
  sh 'rackup -Ilib demo/config.ru'
end

task :default => :test
