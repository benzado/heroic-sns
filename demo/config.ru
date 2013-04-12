require 'erb'
require 'heroic/sns'

# `rackup -Ilib` at the command line to start this rack app

class MessageCapture
  def initialize(app)
    @app = app
  end
  def call(env)
    if message = env['sns.message']
      path = "#{message.id}.txt"
      File.open(path, 'w') { |f| f.write(message.to_json) } unless File.exists?(path)
    end
    @app.call(env)
  end
end

class DemoApp

  def initialize
    @events = Array.new
    @template = ERB.new(File.read(File.join(File.dirname(__FILE__), 'demo.erb')))
  end

  def call(env)
    if error = env['sns.error']
      @events << error
      puts "SNS Error: #{error}"
      response(500, 'Error')
    elsif message = env['sns.message']
      @events << message
      puts "*** MESSAGE #{message.id} RECEIVED ***"
      puts "Subject: #{message.subject}\n\n" if message.subject
      puts message.body
      puts "*** END MESSAGE ***"
      response(200, 'OK')
    else
      content = @template.result(binding)
      [200, { 'Content-Type' => 'text/html' }, [ content ]]
    end
  end

  def response(code, text)
    [code, {'Content-Type' => 'text/plain', 'Content-Length' => text.length.to_s}, [text]]
  end

end

use Rack::Lint
use Heroic::SNS::Endpoint, topics: Proc.new { true }, auto_confirm: nil, auto_unsubscribe: nil
use Rack::Lint
use MessageCapture
run DemoApp.new
