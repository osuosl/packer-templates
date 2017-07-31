#!/usr/bin/env ruby

# wrapper script which takes a template and give us required things

# when called for running_tests, we need image_name

require 'json'
require 'optparse'
require 'csv'

OPENSTACK_CREDENTIALS_DEFAULT_LOCATION = '/home/alfred/openstack_credentials.json'

fieldname = ''
parser = OptionParser.new do |opts|
  opts.banner = 'Usage: wrapper.rb <template_file1>...<template_fileN> \
  -f <field_name>'

  opts.separator('')
  opts.on('-f F', '--field_name F', 'Specify a single field to extract') do |f|
    fieldname = f || ''
  end
end

def extract_variable_from_template(template, variable)
  t = JSON.parse(open(template).read.to_s)

  case variable
  when 'image_name'
    return t['variables']['image_name']
  when 'output_directory'
    t_builders = t_data.dig('builders')
    # .dig returns nil if it doesn't find that path in the hash.
    next if t_builders.nil?

    t_builders.select! { |p| p['type'] == 'qemu' }
    return t['builders'][0]['output_directory']
  else
    return nil
  end
end

def execute_on_each_cluster(
    openstack_credential_file = OPENSTACK_CREDENTIALS_DEFAULT_LOCATION,
    function
  )
  t = JSON.parse!

  #open openstack_credentials and run deploy for each cluster
  openstack_clusters = JSON.parse(open(openstack_credentials_file).read.to_s)

  openstack_clusters.keys.each do |cluster|
    puts cluster
    puts pr_number
    #bring the credentials to the environment
    ENV.update openstack_clusters[cluster]

    puts "Calling #{function}"
    function()
  end
end
