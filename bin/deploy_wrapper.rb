#!/opt/chef/embedded/bin/ruby
# frozen_string_literal: true

# wrapper around the deploy.sh for deploying things properly.

require 'json'
require 'optparse'
load 'bin/common.rb'

ARGV << '-h' if ARGV.empty?

# Get our commandline arguments parsed by the common function
options = option_parser($PROGRAM_NAME, ARGV)

run_on_each_cluster(options[:openstack_credentials_file]) do
  # name which would have been used to create the qcow2 image and the dir containing it
  vm_name = parse_from_template(options[:template_file], 'vm_name')

  # TODO: check for existence of the built image
  image_path = "./#{vm_name}/#{vm_name}-compressed.qcow2"
  puts "going to look for image at \n #{image_path}"

  # name to use when deploying the image on OpenStack
  openstack_image_name = parse_from_template(options[:template_file], 'image_name')
  chef_version = parse_from_template(options[:template_file], 'chef_version')

  command = "./bin/deploy.sh -f #{image_path} -n \"#{openstack_image_name}\" -r #{options[:pr_number]}"

  # when the command is not specified in the template
  command += "-c #{chef_version}" unless chef_version.nil?

  puts command

  deploy_output = `#{command}`
  puts deploy_output
end
