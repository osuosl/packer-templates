#!/opt/chef/embedded/bin/ruby
# frozen_string_literal: true

# wrapper around the openstack_taster for tasting things properly.

require 'json'
require 'optparse'
load 'bin/common.rb'

ARGV << '-h' if ARGV.empty?

# Get our commandline arguments parsed by the common function
options = option_parser($PROGRAM_NAME, ARGV)

run_on_each_cluster(options[:openstack_credentials_file]) do
  # name which was used for deploying the image
  puts `openstack image list`

  openstack_image_name = parse_from_template(options[:template_file], 'image_name') +
                         " - PR\##{options[:pr_number]}"

  command = "openstack_taster \"#{openstack_image_name}\""
  puts command

  taste_output = `#{command}`
  puts taste_output
end
