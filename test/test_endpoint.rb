require 'test/unit'
require 'heroic/sns'

begin
  # Insert the certificate in the cache so that these tests aren't dependent on
  # network access (or Amazon's decision to keep this cert around).
  cert_url = 'https://sns.us-east-1.amazonaws.com/SimpleNotificationService-f3ecfb7224c7233fe7bb5f59f96de52f.pem'
  cert_data = File.read('test/fixtures/f3ecfb7224c7233fe7bb5f59f96de52f.pem')
  Heroic::SNS::CERTIFICATE_CACHE[cert_url] = OpenSSL::X509::Certificate.new(cert_data)
end

NULL_APP = Proc.new { |env| [0, {}, []] }

class EndpointTest < Test::Unit::TestCase

  def sns(name)
    @json = File.read("test/fixtures/#{name}.json")
    @msg = Heroic::SNS::Message.new(@json)
    @env = {
      'HTTP_X_AMZ_SNS_MESSAGE_TYPE' => @msg.type,
      'HTTP_X_AMZ_SNS_MESSAGE_ID' => @msg.id,
      'HTTP_X_AMZ_SNS_TOPIC_ARN' => @msg.topic_arn,
      'HTTP_X_AMZ_SNS_SUBSCRIPTION_ARN' => "#{@msg.topic_arn}:af0d2f29-f4c3-4df2-b7e2-5a096fc772f6",
      'rack.input' => StringIO.new(@json)
    }
  end

  def test_no_topic
    assert_raises ArgumentError do
      Heroic::SNS::Endpoint.new
    end
  end

  def test_receive_message
    result = [0, {}, []]
    test = Proc.new do |env|
      assert_equal env['sns.message'], @msg
      result
    end
    sns('notification')
    app = Heroic::SNS::Endpoint.new test, :topic => @msg.topic_arn
    assert_equal result, app.call(@env)
  end

  def test_ignore_message
    test = Proc.new { |env| raise "should be unreachable!" }
    sns('notification')
    app = Heroic::SNS::Endpoint.new test, :topic => "different-topic"
    assert_nothing_raised { app.call(@env) }
  end

end
