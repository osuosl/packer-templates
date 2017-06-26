include_recipe 'certificate::wildcard'

package 'ca-certificates' do
  action :upgrade
end

execute 'copy self-signed ca-cert' do
  command <<-EOF
    cat /etc/pki/tls/certs/wildcard-bundle.crt >> \
      /etc/ssl/certs/ca-bundle.crt && touch /tmp/cacert
  EOF
  creates '/tmp/cacert'
end

# Make sure ruby knows to use the ca-bundle certs as authority so that our self signed cert gets verified properly.
# NOTE: This is only needed for testing, not production.
ruby_block 'set ca_file' do
  block do
    require 'net/https'

    Net::HTTP.class_eval do
      alias_method :_use_ssl=, :use_ssl=

      def use_ssl=(boolean)
        self.ca_file = '/etc/ssl/certs/ca-bundle.crt'
        self._use_ssl = boolean
      end
    end
  end
end
