#!/usr/bin/env ruby

# common functions required by various wrappers

require 'json'
require 'optparse'
require 'csv'

def parse_from_template(template, variable)
  t = JSON.parse(open(template).read.to_s)

  case variable

  when 'image_name'
    return t['variables']['image_name']  if t['variables'].key? 'image_name'
 
    puts "image_name custom variable not pre-set in #{template}!"
    return t['builders'][0]['vm_name'].sub('-', ' ').sub('packer', '').strip

  when 'output_directory'
    t_builders = t.dig('builders')
    # .dig returns nil if it doesn't find that path in the hash.
    return nil if t_builders.nil?

    t_builders.select! { |p| p['type'] == 'qemu' }
    return t['builders'][0]['output_directory']

  when 'vm_name'
    t_builders = t.dig('builders')
    # .dig returns nil if it doesn't find that path in the hash.
    return nil if t_builders.nil?

    t_builders.select! { |p| p['type'] == 'qemu' }
    puts "WARNING: Returning vm_name from builder 0 of #{t_builders.count}" if t_builders.count > 1
    return t['builders'][0]['vm_name']
  else
    return nil
  end
end

def run_on_each_cluster(
    openstack_credentials_file = OPENSTACK_CREDENTIALS_DEFAULT_LOCATION
)

  # open openstack_credentials and run deploy for each cluster
  openstack_clusters = JSON.parse(open(openstack_credentials_file).read.to_s)

  openstack_clusters.keys.each do |cluster|
    puts "cluster is #{cluster}"

    # bring the credentials to the environment
    ENV.update openstack_clusters[cluster]

    # yield whatever the supplied block wants!
    yield
  end
end
