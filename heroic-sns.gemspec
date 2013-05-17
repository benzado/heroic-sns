$:.push File.expand_path("../lib", __FILE__)
require "heroic/sns/version"

# See: http://guides.rubygems.org/specification-reference/

Gem::Specification.new do |s|
  s.name        = 'heroic-sns'
  s.version     = Heroic::SNS::VERSION
  s.summary     = "Lightweight Rack middleware for AWS SNS endpoints"
  s.description = File.read('description.txt')
  s.license     = 'Apache'

  s.author      = "Benjamin Ragheb"
  s.email       = 'ben@benzado.com'
  s.homepage    = 'https://github.com/benzado/heroic-sns'

  s.files       = `git ls-files`.split("\n")

  s.platform = Gem::Platform::RUBY
  s.required_ruby_version = '>= 1.8.7'
  s.add_runtime_dependency 'rack', '~> 1.4'
  s.add_runtime_dependency 'json', '~> 1.7.7'
end
