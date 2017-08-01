#!/opt/chef/embedded/bin/ruby
# wrapper around the deploy.sh for deploying things properly.

require 'json'
require 'optparse'
load 'bin/common.rb'

options = {}
OPENSTACK_CREDENTIALS_DEFAULT_LOCATION = '/home/alfred/openstack_credentials.json'
openstack_credentials_file = OPENSTACK_CREDENTIALS_DEFAULT_LOCATION
pr_number = 29

template_file = ''
#TODO: fix this parser to make things mandatory and collect parameters properly

parser = OptionParser.new do |opts|
  opts.banner = 'Usage: deploy_wrapper.rb -t <template_file> -s OPENSTACK_CREDENTIALS_FILE -r PR'

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
          'Specify the PR number for which we are deploying this.') do |r|
    pr_number = r || 29
  end
end

params = parser.parse!
puts params

run_on_each_cluster(openstack_credentials_file) do |cluster|
  # name which would have been used to create the qcow2 image and the dir containing it
  vm_name = extract_variable_from_template(template_file, 'vm_name')

  # TODO: check for existence of the built image
  image_path = "./#{vm_name}/#{vm_name}-compressed.qcow2"
  puts "going to look for image at \n #{image_path}"

  # name to use when deploying the image on OpenStack
  openstack_image_name = extract_variable_from_template(template_file, 'image_name')

  command = "./bin/deploy.sh -f #{image_path} -n \"#{openstack_image_name}\" -r #{pr_number}"
  puts command 

  deploy_output = `#{command}`
  puts deploy_output
end
