require 'test/unit'
require 'heroic/sns'
require 'helper'
class CertificateCacheTest < Test::Unit::TestCase

  def test_bad_url_raises
    assert_raises Heroic::SNS::Error do  
      Heroic::SNS::CertificateCache.instance.get_certificate("httpbad:://google")
    end
  end

  def test_store_is_cleared
    bad_hash={}
    (Heroic::SNS::CertificateCache::MAXIMUM_ALLOWED_CERTIFICATES + 1).times{|i| bad_hash[i]=i}
    Heroic::SNS::CertificateCache.instance.load(bad_hash)
    assert_raises Heroic::SNS::Error do  
      Heroic::SNS::CertificateCache.instance.get_certificate(33)
    end
  end
  def test_store_is_not_cleared_early

    bad_hash={}
    (Heroic::SNS::CertificateCache::MAXIMUM_ALLOWED_CERTIFICATES ).times{|i| bad_hash[i]=i}
    Heroic::SNS::CertificateCache.instance.load(bad_hash)
    assert_equal 4, Heroic::SNS::CertificateCache.instance.get_certificate(4)
  end
end
