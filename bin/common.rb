#!/usr/bin/env ruby
# frozen_string_literal: true

# common functions required by various wrappers

require 'json'
require 'optparse'
require 'csv'

OPENSTACK_CREDENTIALS_DEFAULT_LOCATION = '/tmp/packer_pipeline_creds.json'

def option_parser(for_program, argv)
  options = {}

  parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{for_program} -t <template_file> -s OPENSTACK_CREDENTIALS_FILE -r PR"

    opts.separator('')
    opts.on('-t TEMPLATE_FILE',
            '--template_file TEMPLATE_FILE',
            'Specify the template to deploy.') do |t|
      options[:template_file] = t
    end

    opts.on('-s OPENSTACK_CREDENTIALS_JSON_FILE',
            '--openstack_credentials OPENSTACK_CREDENTIALS_JSON_FILE',
            'Specify the JSON file with the OpenStack cluster credentials to use.') do |j|
      options[:openstack_credentials_file] = j || OPENSTACK_CREDENTIALS_DEFAULT_LOCATION
    end

    opts.on('-r PR',
            '--pull_request PR',
            'Specify the PR number for which we are deploying this.') do |r|
      options[:pr_number] = r
    end

    opts.on_tail('-h', '--help', 'Prints this help text') do
      puts opts
      exit
    end
  end

  parser.parse! argv

  if !options.key?(:template_file) ||
     !options.key?(:openstack_credentials_file) ||
     !options.key?(:pr_number)

    puts "All parameters are mandatory but you just passed #{options}!"
    exit 1
  end

  unless File.readable? options[:openstack_credentials_file]
    puts "#{options[:openstack_credentials_file]} not readable!"
    exit 2
  end

  unless File.readable? options[:template_file]
    puts "#{options[:template_file]} not readable!"
    exit 3
  end

  p options
  options
end

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

  when 'vm_name', 'openstack_image_name'
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
