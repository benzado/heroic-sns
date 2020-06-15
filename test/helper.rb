# Generate a self-signed certificate
# 1. openssl genrsa -out sns.key 1024
# 2. openssl req -new -key sns.key -out sns.csr
# 3. openssl x509 -req -days 3652 -in sns.csr -signkey sns.key -out sns.crt

module Heroic
  module SNS
    # Use a fake certificate cache so tests aren't dependent on
    # network access, or the fact that the certificate is also fake.
    CERTIFICATE_CACHE = Class.new do
      def cert_data
        File.read('test/fixtures/sns.crt')
      end

      def get(_)
        @cert ||= OpenSSL::X509::Certificate.new(cert_data)
      end
    end.new

    TEST_CERT_URL = 'https://sns.xx-east-1.amazonaws.com/self-signed.pem'
    TEST_CERT_KEY = OpenSSL::PKey::RSA.new(File.read('test/fixtures/sns.key'))

    class Message
      def update_timestamp!(t = Time.now)
        @msg['Timestamp'] = t.utc.xmlschema(3)
      end

      def update_signing_cert_url!(url = nil)
        @msg['SigningCertURL'] = url || TEST_CERT_URL
      end

      def sign!
        signature = TEST_CERT_KEY.sign(OpenSSL::Digest::SHA1.new, string_to_sign)
        @msg['Signature'] = Base64::encode64(signature)
      end
    end
  end
end
