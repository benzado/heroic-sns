require 'test/unit'
require 'heroic/sns'
require 'helper'

class MessageTest < Test::Unit::TestCase
  def sns(name, options = {})
    json = File.read("test/fixtures/#{name}.json")
    msg = Heroic::SNS::Message.new(json)
    msg.update_timestamp!(options[:timestamp] || Time.now)
    msg.update_signing_cert_url!(options[:signing_cert_url])
    msg.sign!
    return msg
  end

  def test_invalid_json
    assert_raises Heroic::SNS::Error do
      Heroic::SNS::Message.new("INV4L!D JS0N")
    end
  end

  def test_notification
    msg = sns("notification")
    assert_equal 'Notification', msg.type
    assert_equal 'arn:aws:sns:us-east-1:777594007835:racktest', msg.topic_arn
    assert_equal 128, msg.signature.length
    assert_nothing_raised { msg.verify! }
  end

  def test_subscription
    msg = sns("subscription")
    assert_equal 'SubscriptionConfirmation', msg.type
    assert_equal 'arn:aws:sns:us-east-1:777594007835:racktest', msg.topic_arn
    assert_equal 128, msg.signature.length
    assert_nothing_raised { msg.verify! }
  end

  def test_unsubscribe
    msg = sns("unsubscribe")
    assert_equal 'UnsubscribeConfirmation', msg.type
    assert_equal 'arn:aws:sns:us-east-1:777594007835:racktest', msg.topic_arn
    assert_equal 128, msg.signature.length
    assert_nothing_raised { msg.verify! }
  end

  def test_tampered
    json = sns("notification").to_json
    msg = Heroic::SNS::Message.new(json.gsub(/booyakasha/, 'cowabunga'))
    assert_equal 'cowabunga!', msg.body
    assert_raises Heroic::SNS::Error do
      msg.verify!
    end
  end

  def test_untrusted_cert_url_s3
    cert_url = 'https://sns.s3.amazonaws.com/self-signed.pem'
    msg = sns("notification", :signing_cert_url => cert_url)
    assert_equal cert_url, msg.signing_cert_url
    assert_raises Heroic::SNS::Error do
      msg.verify!
    end
  end

  def test_untrusted_cert_url_other
    cert_url = 'https://example.com/sns.us-east-1.amazonaws.com/self-signed.pem'
    msg = sns("subscription", :signing_cert_url => cert_url)
    assert_equal cert_url, msg.signing_cert_url
    assert_raises Heroic::SNS::Error do
      msg.verify!
    end
  end

  # Generate tests for every known AWS SNS endpoint.
  # https://docs.aws.amazon.com/general/latest/gr/sns.html
  File.read('test/fixtures/aws-sns-endpoints.txt').split(/\n/).each do |domain|
    define_method("test_trusted_cert_url_#{domain}") do
      cert_url = "https://#{domain}/certificate.pem"
      msg = sns("notification", :signing_cert_url => cert_url)
      assert_equal cert_url, msg.signing_cert_url
      assert_nothing_raised { msg.verify! }
    end
  end

  def test_expired
    t = Time.utc(1984, 5)
    msg = sns("notification", :timestamp => t)
    assert_equal t, msg.timestamp
    assert_raises Heroic::SNS::Error do
      msg.verify!
    end
  end
end
