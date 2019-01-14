require 'spec_helper_acceptance'
require 'openssl'

describe 'BitBucket Secret Enabled, System Ruby with No SSL, Not protected, No mcollective' do
  context 'default parameters' do
    pp = %(
      class { 'r10k':
        remote => 'git@yourbitbucketserver.com:someuser/puppet.git',
      }
      class {'r10k::webhook::config':
        enable_ssl       => false,
        protected        => false,
        use_mcollective  => false,
        bitbucket_secret => 'secret',
      }

      class {'r10k::webhook':
        require => Class['r10k::webhook::config'],
      }
    )

    it 'applies with no errors' do
      apply_manifest(pp, catch_failures: true)
    end
    it 'is idempotent' do
      apply_manifest(pp, catch_changes: true)
    end
    describe service('webhook') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    context 'supports style BitBucket payloads via module end point with signature in header' do
      HMAC_DIGEST = OpenSSL::Digest.new('sha256')
      signature = 'sha1=' + OpenSSL::HMAC.hexdigest(HMAC_DIGEST, 'secret', '{ "repository": { "name": "puppetlabs-stdlib" } }')

      describe command("/usr/bin/curl -d '{ \"repository\": { \"name\": \"puppetlabs-stdlib\" } }' -H \"Accept: application/json\" \"http://localhost:8088/module\" -H \"X-Hub-Signature: #{signature}\" -k -q") do
        its(:stdout) { is_expected.not_to match %r{.*You shall not pass.*} }
        its(:exit_status) { is_expected.to eq 0 }
      end
    end
    context 'supports style BitBucket payloads via payload end point with signature in header' do
      HMAC_DIGEST = OpenSSL::Digest.new('sha256')
      signature = 'sha1=' + OpenSSL::HMAC.hexdigest(HMAC_DIGEST, 'secret', '{ "ref": "refs/heads/production" }')

      describe command("/usr/bin/curl -d '{ \"ref\": \"refs/heads/production\" }' -H \"Accept: application/json\" -H \"X-Hub-Signature: #{signature}\" \"http://localhost:8088/payload\" -k -q") do
        its(:stdout) { is_expected.not_to match %r{.*You shall not pass.*} }
        its(:exit_status) { is_expected.to eq 0 }
      end
    end
  end
end
