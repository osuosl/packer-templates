#!/opt/chef/embedded/bin/ruby
# wrapper around the deploy.sh for deploying things properly.

require 'json'
require 'optparse'

options = {}
OPENSTACK_CREDENTIALS_DEFAULT_LOCATION = '/home/alfred/openstack_credentials.json'
openstack_credentials_file = OPENSTACK_CREDENTIALS_DEFAULT_LOCATION
pr_number = 29

template_file = ''

parser = OptionParser.new do |opts|
  opts.banner = 'Usage: deploy_wrapper.rb -t <template_file>'

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

  opts.on('-p PR', 
          '--pull_request PR',
          'Specify the PR number for which we are deploying this.') do |r|
    pr_number = r || 29
  end
end


params = parser.parse!
puts params

#template_file = params[0]
puts "Processing #{template_file}"

#TODO: check for existence of template file 
template_json = JSON.parse(open(template_file).read.to_s)
image_name = template_json['variables']['image_name']

template_name = "packer-#{template_file}".sub('.json','')
image_path = "./#{template_name}/#{template_name.sub('-openstack','')}-compressed.qcow2"
#TODO: check for existence of the built image

#open openstack_credentials and run deploy for each cluster
openstack_clusters = JSON.parse(open(openstack_credentials_file).read.to_s)

openstack_clusters.keys.each do |cluster|

  puts cluster
  puts pr_number
  #bring the credentials to the environment
  ENV.update openstack_clusters[cluster]

  command = "./bin/deploy.sh -f \"#{image_path}\" -n \"#{image_name}\" -r #{pr_number}"
  puts command 
  deploy_output = `#{command}`

  puts deploy_output
end
