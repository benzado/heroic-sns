require 'openssl'
require 'open-uri'

module Heroic
  module SNS

    SUBSCRIPTION_ARN_HTTP_HEADER = 'HTTP_X_AMZ_SNS_SUBSCRIPTION_ARN'

=begin rdoc

  Heroic::SNS::Endpoint is Rack middleware which intercepts messages from
  Amazon's Simple Notification Service (SNS). It makes the parsed and
  verified message available to your application in the Rack environment
  under the 'sns.message' key. If an error occurred during message handling,
  the error is available in the Rack environment in the 'sns.error' key.

  Endpoint is to be initialized with a hash of options. It understands three
  different options:

  +:topic+ (or +:topics+) specifies a filter that defines what SNS topics
  are handled by this endpoint ("on-topic"). You can supply any of the
  following:
  - a topic ARN as a String
  - a list of topic ARNs as an Array of Strings
  - a regular expression matching on-topic ARNs
  - a Proc which takes a topic ARN as a String and returns true or false.
  You *must* specify a topic filter. Use <code>Proc.new{true}</code> if
  you insist on indiscriminately accepting all notifications.

  +:auto_confirm+ determines how SubscriptionConfirmation messages are handled.
  - If true, the subscription is confirmed and your app is not notified.
    This is the default.
  - If false, the subscription is ignored and your app is not notified.
  - If nil, the message is passed along to your app.

  +:auto_resubscribe+ affects how on-topic UnsubscribeConfirmation messages are handled.
  - If false, they are ignored and your app is also not notified.
    This is the default.
  - If true, they topic is automatically re-subscribed by retrieving the URL in
    the `SubscribeURL` field of the SNS message, and your app is not notified.
  - If nil, there is no special handling and the message is passed along to your
    app.

  You can install this in your config.ru:
    use Heroic::SNS::Endpoint, :topics => /whatever/

  For Rails, you can also install it in /config/initializers/sns_endpoint.rb:
    Rails.application.config.middleware.use Heroic::SNS::Endpoint, :topic => ...

=end

    class Endpoint

      DEFAULT_OPTIONS = { :auto_confirm => true, :auto_resubscribe => false }

      def initialize(app, opt = {})
        @app = app
        options = DEFAULT_OPTIONS.merge(opt)
        @auto_confirm = options[:auto_confirm]
        @auto_resubscribe = options[:auto_resubscribe]
        if 1 < [:topic, :topics].count { |k| options.has_key?(k) }
          raise ArgumentError.new("supply zero or one of :topic, :topics")
        end
        @topic_filter = begin
          case a = options[:topic] || options[:topics]
          when String then Proc.new { |t| a == t }
          when Regexp then Proc.new { |t| a.match(t) }
          when Proc then a
          when Array
            unless a.all? { |e| e.is_a? String }
              raise ArgumentError.new("topic array must be strings")
            end
            Proc.new { |t| a.include?(t) }
          when nil
            raise ArgumentError.new("must specify a topic filter!")
          else
            raise ArgumentError.new("can't use topic filter of type #{a.class}")
          end
        end
      end

      def call(env)
        if topic_arn = env['HTTP_X_AMZ_SNS_TOPIC_ARN']
          if @topic_filter.call(topic_arn)
            call_on_topic(env)
          else
            call_off_topic(env)
          end
        else
          @app.call(env)
        end
      end

      private

      OK_RESPONSE = [200, {'Content-Type' => 'text/plain'}, []]

      # Confirms that values specified in HTTP headers match those in the message
      # itself.
      def check_headers!(message, env)
        h = env.values_at 'HTTP_X_AMZ_SNS_MESSAGE_TYPE', 'HTTP_X_AMZ_SNS_MESSAGE_ID', 'HTTP_X_AMZ_SNS_TOPIC_ARN'
        m = message.type, message.id, message.topic_arn
        raise Error.new("message does not match HTTP headers", message) unless h == m
      end

      # Behavior for "on-topic" messages. Notifications are always passed along
      # to the app. Confirmations are passed along only if their respective
      # option is nil. If true, the subscription is confirmed; if false, it is
      # simply ignored.
      def call_on_topic(env)
        begin
          message = Message.new(env['rack.input'].read)
          env['rack.input'].rewind
          check_headers!(message, env)
          message.verify!
          case message.type
          when 'SubscriptionConfirmation'
            URI.parse(message.subscribe_url).open if @auto_confirm
            return OK_RESPONSE unless @auto_confirm.nil?
          when 'UnsubscribeConfirmation'
            URI.parse(message.subscribe_url).open if @auto_resubscribe
            return OK_RESPONSE unless @auto_resubscribe.nil?
          end
          env['sns.message'] = message
        rescue OpenURI::HTTPError => e
          env['sns.error'] = Error.new("unable to subscribe: #{e.message}; URL: #{message.subscribe_url}", message)
        rescue Error => e
          env['sns.error'] = e
        end
        @app.call(env)
      end

      # Default behavior for "off-topic" messages. Subscription and unsubscribe
      # confirmations are simply ignored. Notifications, however, indicate that
      # we are subscribed to a topic we don't know how to deal with. In this
      # case, we automatically unsubscribe (if the message is authentic).
      def call_off_topic(env)
        if env['HTTP_X_AMZ_SNS_MESSAGE_TYPE'] == 'Notification'
          begin
            message = Message.new(env['rack.input'].read)
            message.verify!
            URI.parse(message.unsubscribe_url).open
          rescue => e
            raise Error.new("error handling off-topic notification: #{e.message}", message)
          end
        end
        OK_RESPONSE
      end

    end

  end
end
