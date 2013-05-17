require 'heroic/sns/version'
require 'heroic/sns/message'
require 'heroic/sns/endpoint'

module Heroic
  module SNS

    class Error < ::StandardError

      # The message that triggered this error, if available.
      attr_reader :sns_message

      def initialize(error_message, sns_message = nil)
        super(error_message)
        @sns_message = sns_message
      end

    end

  end
end
