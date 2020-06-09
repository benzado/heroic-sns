require 'json'
require 'base64'
require 'heroic/lru_cache'

module Heroic
  module SNS

    MAXIMUM_ALLOWED_AGE = 3600 # reject messages older than one hour
    MAXIMUM_ALLOWED_CERTIFICATES = 50

    CERTIFICATE_CACHE = Heroic::LRUCache.new(MAXIMUM_ALLOWED_CERTIFICATES) do |cert_url|
      begin
        cert_data = open(cert_url)
        OpenSSL::X509::Certificate.new(cert_data.read)
      rescue OpenSSL::X509::CertificateError => e
        raise SNS::Error.new("unable to parse signing certificate: #{e.message}; URL: #{cert_url}")
      rescue => e
        raise SNS::Error.new("unable to retrieve signing certificate: #{e.message}; URL: #{cert_url}")
      end
    end

    # Encapsulates an SNS message. Since Endpoint takes care of authenticating
    # the message, most of the time you will simply be interested in retrieving
    # the +subject+ and +body+ from the message and acting on it.
    #
    # See: http://docs.aws.amazon.com/sns/latest/gsg/json-formats.html
    class Message

      def initialize(json)
        @msg = ::JSON.parse(json)
      rescue JSON::ParserError => e
        raise Error.new("failed to parse message as JSON: #{e.message}")
      end

      # The message type will be one of +SubscriptionConfirmation+,
      # +UnsubscribeConfirmation+, and +Notification+.
      def type
        @msg['Type']
      end

      def topic_arn
        @msg['TopicArn']
      end

      # A Universally Unique Identifier, unique for each message published. For
      # a notification that Amazon SNS resends during a retry, the message ID of
      # the original message is used.
      def id
        @msg['MessageId']
      end

      # The timestamp when the message was published, as a Time object.
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

      # The message payload. As far as Amazon and this class are concerned, the
      # message payload is just a string of bytes. If you are expecting, for
      # example, a JSON object, you will need to pass this to a JSON parser.
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
      # the +subscribe_url+, you can ignore this field.
      def token
        @msg['Token']
      end

      def ==(other)
        other.is_a?(Message) && @msg == other.instance_variable_get(:@msg)
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

      # Returns a JSON serialization of the message. Note that it may not be
      # identical to the serialization that was retrieved from the network.
      def to_json
        @msg.to_json
      end

      # Verifies the message signature. Raises Error if it is not valid.
      #
      # See: http://docs.aws.amazon.com/sns/latest/gsg/SendMessageToHttp.verify.signature.html
      def verify!
        age = Time.now - timestamp
        raise Error.new("timestamp is in the future", self) if age < 0
        raise Error.new("timestamp is too old", self) if age > MAXIMUM_ALLOWED_AGE
        if signature_version != '1'
          raise Error.new("unknown signature version: #{signature_version}", self)
        end
        if signing_cert_url !~ %r{\Ahttps://sns\.[a-z]{2}(?:-gov)?-(?:north|south|east|west|central){1,2}-\d+\.amazonaws\.com/}
          raise Error.new("signing certificate is not from amazonaws.com", self)
        end
        text = string_to_sign # will warn of invalid Type
        cert = CERTIFICATE_CACHE.get(signing_cert_url)
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
