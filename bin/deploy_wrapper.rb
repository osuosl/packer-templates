#!/opt/chef/embedded/bin/ruby
# frozen_string_literal: true

# wrapper around the deploy.sh for deploying things properly.

require 'json'
require 'optparse'
load 'bin/common.rb'

ARGV << '-h' if ARGV.empty?

# Get our commandline arguments parsed by the common function
options = option_parser($PROGRAM_NAME, ARGV)

#run_on_each_cluster(options[:openstack_credentials_file]) do
  # name which would have been used to create the qcow2 image and the dir containing it
  vm_name = parse_from_template(options[:template_file], 'vm_name')
  output_directory = parse_from_template(options[:template_file], 'output_directory')

  image_path = "./#{output_directory}/#{vm_name}"
  image_path += if vm_name["x86"]
                  "-converted.raw"
                else
                  "-compressed.qcow2"
                end
  puts "going to look for image at \n #{image_path}"

  unless File.exist? image_path
    puts "No file found at #{image_path}! Quitting."
    return 2
  end

  # name to use when deploying the image on OpenStack
  openstack_image_name = parse_from_template(options[:template_file], 'image_name')
  chef_version = parse_from_template(options[:template_file], 'chef_version')

  command = "./bin/deploy.sh -n \"#{openstack_image_name}\" -r #{options[:pr_number]}"
  if options[:publish]
    # publish image if option is set
    command += ' -p' if options[:publish]
  else
    command += " -f #{image_path}"
    # when the chef_version is not specified in the template, don't use it!
    command += " -c #{chef_version}" unless chef_version.nil?
    if image_name["x86"]
      command += ' -d raw'
      command += ' -o "' + \
        %w(
          hw_scsi_model=virtio-scsi
          hw_disk_bus=scsi
          hw_qemu_guest_agent=yes
          os_require_quiesce=yes
        ).map do |property|
          " --property #{property}"
        end.join + \
        '"'
    else
      command += ' -d qcow2'
    end
  end

  puts command
  exit 0
  system(command)
  exit $?.exitstatus
#end
