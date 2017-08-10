#!/opt/chef/embedded/bin/ruby
# wrapper around the openstack_taster for tasting things properly.

require 'json'
require 'optparse'
load 'bin/common.rb'

options = {}
OPENSTACK_CREDENTIALS_DEFAULT_LOCATION = '/tmp/packer_pipeline_creds.json'
openstack_credentials_file = OPENSTACK_CREDENTIALS_DEFAULT_LOCATION
template_file = ''
pr_number = ''

#TODO: fix this parser to make things mandatory and collect parameters properly

parser = OptionParser.new do |opts|
  opts.banner = 'Usage: taster_wrapper.rb -t <template_file> -s OPENSTACK_CREDENTIALS_FILE -r PR'

  opts.separator('')
  opts.on('-t TEMPLATE_FILE',
          '--template_file TEMPLATE_FILE',
          'Specify the template to deploy.') do |t|
    template_file = t
  end

  opts.on('-s OPENSTACK_CREDENTIALS_JSON_FILE',
          '--openstack_credentials OPENSTACK_CREDENTIALS_JSON_FILE',
          'Specify the JSON file containing the OpenStack cluster credentials to use.') do |j|
    openstack_credentials_file = j || OPENSTACK_CREDENTIALS_DEFAULT_LOCATION
  end

  opts.on('-r PR',
          '--pull_request PR',
          'Specify the PR number for which we are testing this') do |r|
    pr_number = r || 29
  end
end

params = parser.parse!
puts params

run_on_each_cluster(openstack_credentials_file) do |cluster|
  # name which was used for deploying the image
  openstack_image_name = parse_from_template(template_file, 'image_name') + 
                         " - PR\##{pr_number}"

  puts ENV['OS_USERNAME']
  puts ENV['OS_TENANT_NAME']
  `export -p > /home/alfred/#{cluster}.rc`

  command = "openstack_taster \"#{openstack_image_name}\""
  puts command 

  taste_output = `#{command}`
  puts taste_output
end
