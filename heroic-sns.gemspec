$:.push File.expand_path("../lib", __FILE__)
require "heroic/sns/version"

# See: http://guides.rubygems.org/specification-reference/

Gem::Specification.new do |s|
  s.name        = 'heroic-sns'
  s.version     = Heroic::SNS::VERSION
  s.summary     = "Lightweight Rack middleware for AWS SNS endpoints"
  s.description = <<-EOD
Secure, lightweight Rack middleware for Amazon Simple Notification Service (SNS)
endpoints. SNS messages are intercepted, parsed, verified, and then passed along
to the web application via the 'sns.message' environment key. Heroic::SNS has no
dependencies besides Rack (specifically, the aws-sdk gem is not needed).
SNS message signatures are verified in order to reject forgeries and replay
attacks.
EOD

  s.license     = 'Apache'

  s.author      = "Benjamin Ragheb"
  s.email       = 'ben@benzado.com'
  s.homepage    = 'https://github.com/benzado/heroic-sns'

  s.files       = `git ls-files`.split("\n")

  s.platform = Gem::Platform::RUBY
  s.required_ruby_version = '>= 1.8.7'
  s.add_development_dependency 'rdoc', '~> 4.0'
  s.add_development_dependency 'test-unit', '1.2.3'
  s.add_runtime_dependency 'rack', '>= 1.4'
  s.add_runtime_dependency 'json', '>= 1.7'
end
