#!/opt/chef/embedded/bin/ruby
# frozen_string_literal: true

# wrapper around the openstack_taster for tasting things properly.

require 'json'
require 'optparse'
require 'English'
load 'bin/common.rb'

ARGV << '-h' if ARGV.empty?

# Get our commandline arguments parsed by the common function
options = option_parser($PROGRAM_NAME, ARGV)

run_on_each_cluster(options[:openstack_credentials_file]) do
  # name which was used for deploying the image
  puts `openstack image list`

  image_name = parse_from_template(options[:template_file], 'image_name') + " - PR\##{options[:pr_number]}"
  ssh_username = parse_from_template(options[:template_file], 'ssh_username')
  flavor = parse_from_template(options[:template_file], 'flavor')

  command = "openstack_taster -i \"#{image_name}\" -u #{ssh_username}"
  command += " -f #{flavor}" unless flavor.nil?
  puts command

  # execute while handing over STDIN,STDOUT and STDERR to the openstack_taster command
  system(command)
  exit $CHILD_STATUS.exitstatus
end
