# See: http://guides.rubygems.org/specification-reference/

Gem::Specification.new do |s|
  s.name        = 'heroic-sns'
  s.version     = '1.0.0'
  s.summary     = "Lightweight Rack middleware for AWS SNS endpoints"
  s.description = File.read('description.txt')

  s.files       = %w[ README.md LICENSE ]
  s.files      += Dir['lib/**/*.rb']
  s.files      += Dir['test/**']

  s.required_ruby_version = '>= 1.8.7'
  s.add_runtime_dependency 'rack', '~> 1.4'

  s.author      = "Benjamin Ragheb"
  s.email       = 'ben@benzado.com'
  s.homepage    = 'https://github.com/benzado/heroic-sns'

  s.post_install_message = "Thanks for installing!"
end
