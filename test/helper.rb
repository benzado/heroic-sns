# Generate a self-signed certificate
# 1. openssl genrsa -out sns.key 1024
# 2. openssl req -new -key sns.key -out sns.csr
# 3. openssl x509 -req -days 3652 -in sns.csr -signkey sns.key -out sns.crt

module Heroic
  module SNS
=begin
    TEST_CERT_URL = 'https://sns.test.amazonaws.com/self-signed.pem'
    TEST_CERT_KEY = OpenSSL::PKey::RSA.new(File.read('test/fixtures/sns.key'))

    CERTIFICATE_CACHE[TEST_CERT_URL] = begin
      # Insert the certificate in the cache so that these tests aren't dependent
      # on network access (or the fact that the certificate is fake).
      cert_data = File.read('test/fixtures/sns.crt')
      OpenSSL::X509::Certificate.new(cert_data)
    end
=end
    class Message

      def update_timestamp!(t = Time.now)
        @msg['Timestamp'] = t.utc.xmlschema(3)
      end

      def sign!
        @msg['SigningCertURL'] = TEST_CERT_URL
        signature = TEST_CERT_KEY.sign(OpenSSL::Digest::SHA1.new, string_to_sign)
        @msg['Signature'] = Base64::encode64(signature)
      end

    end

  end
end
