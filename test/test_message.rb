require 'test/unit'
require 'heroic/sns'

begin
  # Insert the certificate in the cache so that these tests aren't dependent on
  # network access (or Amazon's decision to keep this cert around).
  cert_url = 'https://sns.us-east-1.amazonaws.com/SimpleNotificationService-f3ecfb7224c7233fe7bb5f59f96de52f.pem'
  cert_data = File.read('test/fixtures/f3ecfb7224c7233fe7bb5f59f96de52f.pem')
  Heroic::SNS::CERTIFICATE_CACHE[cert_url] = OpenSSL::X509::Certificate.new(cert_data)
end

class MessageTest < Test::Unit::TestCase

  def sns(name)
    json = File.read("test/fixtures/#{name}.json")
    Heroic::SNS::Message.new(json)
  end

  def test_invalid_json
    assert_raises Heroic::SNS::Error do
      Heroic::SNS::Message.new("INV4L!D JS0N")
    end
  end

  def test_notification
    msg = sns("notification")
    assert_equal 'Notification', msg.type
    assert_in_delta Time.at(1365537372).utc, msg.timestamp, 0.6
    assert_equal 128, msg.signature.length
    assert_nothing_raised { msg.verify! }
  end

  def test_subscription
    msg = sns("subscription")
    assert_equal 'SubscriptionConfirmation', msg.type
    assert_in_delta Time.at(1365536679).utc, msg.timestamp, 0.6
    assert_equal 128, msg.signature.length
    assert_nothing_raised { msg.verify! }
  end

  def test_unsubscribe
    msg = sns("unsubscribe")
    assert_equal 'UnsubscribeConfirmation', msg.type
    assert_in_delta Time.at(1365537652).utc, msg.timestamp, 0.6
    assert_equal 128, msg.signature.length
    assert_nothing_raised { msg.verify! }
  end

  def test_tampered
    msg = sns("notification-tampered")
    assert_equal 'cowabunga!', msg.body
    assert_raises Heroic::SNS::Error do
      msg.verify!
    end
  end

end
