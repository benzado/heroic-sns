# Generate a self-signed certificate
# 1. openssl genrsa -out sns.key 1024
# 2. openssl req -new -key sns.key -out sns.csr
# 3. openssl x509 -req -days 3652 -in sns.csr -signkey sns.key -out sns.crt

module Heroic
  module SNS

    TEST_CERT_URL = 'https://sns.xx-east-1.amazonaws.com/self-signed.pem'
    TEST_CERT_KEY = OpenSSL::PKey::RSA.new(File.read('test/fixtures/sns.key'))
    FAKE_CERT_URL_S3 = 'https://sns.s3.amazonaws.com/self-signed.pem'
    FAKE_CERT_URL_OTHER = 'https://example.com/sns.us-east-1.amazonaws.com/self-signed.pem'

    begin
      # Insert the certificate in the cache so that these tests aren't dependent
      # on network access (or the fact that the certificate is fake).
      cert_data = File.read('test/fixtures/sns.crt')
      cert = OpenSSL::X509::Certificate.new(cert_data)
      CERTIFICATE_CACHE.put(TEST_CERT_URL, cert)
      CERTIFICATE_CACHE.put(FAKE_CERT_URL_S3, cert)
      CERTIFICATE_CACHE.put(FAKE_CERT_URL_OTHER, cert)
    end

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
