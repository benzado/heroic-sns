require 'json'
require 'base64'

module Heroic
  module SNS

    CERTIFICATE_CACHE = Hash.new do |cache, cert_url|
      begin
        cert_data = open(cert_url)
        cache[cert_url] = OpenSSL::X509::Certificate.new(cert_data.read)
      rescue OpenURI::HTTPError => e
        raise Error.new("unable to retrieve signing certificate: #{e.message}; URL: #{cert_url}")
      rescue OpenSSL::X509::CertificateError => e
        raise Error.new("unable to parse signing certificate: #{e.message}; URL: #{cert_url}")
      end
    end

    # Encapsulates an SNS message.
    # See: http://docs.aws.amazon.com/sns/latest/gsg/json-formats.html
    class Message

      def initialize(json)
        @msg = ::JSON.parse(json)
      rescue JSON::ParserError => e
        raise Error.new("failed to parse message as JSON: #{e.message}")
      end

      def type
        @msg['Type']
      end

      def topic_arn
        @msg['TopicArn']
      end

      def id
        @msg['MessageId']
      end

      # The timestamp as a Time object.
      def timestamp
        Time.xmlschema(@msg['Timestamp'])
      end

      def signature_version
        @msg['SignatureVersion']
      end

      def signing_cert_url
        @msg['SigningCertURL']
      end

      # The message signature data, Base-64 decoded.
      def signature
        Base64::decode64(@msg['Signature'])
      end

      # The message may not have a subject.
      def subject
        @msg['Subject']
      end

      def body
        @msg['Message']
      end

      def subscribe_url
        @msg['SubscribeURL']
      end

      def unsubscribe_url
        @msg['UnsubscribeURL']
      end

      # The token is used to confirm subscriptions via the SNS API. If you visit
      # the :subscribe_url, you can ignore this field.
      def token
        @msg['Token']
      end

      def ==(other_message)
        @msg == other_message.instance_variable_get(:@msg)
      end

      def hash
        @msg.hash
      end

      def to_s
        string = "<SNSMessage:\n"
        @msg.each do |k,v|
          string << sprintf("  %s: %s\n", k, v.inspect)
        end
        string << ">"
      end

      def to_json
        @msg.to_json
      end

      # Verifies the message signature. Raises an exception if it is not valid.
      # See: http://docs.aws.amazon.com/sns/latest/gsg/SendMessageToHttp.verify.signature.html
      def verify!
        if signature_version != '1'
          raise Error.new("unknown signature version: #{signature_version}", self)
        end
        if signing_cert_url !~ %r[^https://.*amazonaws\.com/]
          raise Error.new("signing certificate is not from amazonaws.com", self)
        end
        text = string_to_sign # will warn of invalid Type
        cert = CERTIFICATE_CACHE[signing_cert_url]
        digest = OpenSSL::Digest::SHA1.new
        unless cert.public_key.verify(digest, signature, text)
          raise Error.new("message signature is invalid", self)
        end
      end

      private

      CANONICAL_NOTIFICATION_KEYS = %w[Message MessageId Subject Timestamp TopicArn Type].freeze

      CANONICAL_SUBSCRIPTION_KEYS = %w[Message MessageId SubscribeURL Timestamp Token TopicArn Type].freeze

      CANONICAL_KEYS_FOR_TYPE = {
        'Notification' => CANONICAL_NOTIFICATION_KEYS,
        'SubscriptionConfirmation' => CANONICAL_SUBSCRIPTION_KEYS,
        'UnsubscribeConfirmation' => CANONICAL_SUBSCRIPTION_KEYS
      }.freeze

      def string_to_sign
        keys = CANONICAL_KEYS_FOR_TYPE[self.type]
        raise Error.new("unrecognized message type: #{self.type}", self) unless keys
        string = String.new
        keys.each do |key|
          if @msg.has_key?(key) # in case message has no Subject
            string << key << "\n" << @msg[key] << "\n"
          end
        end
        return string
      end

    end
  end
end
