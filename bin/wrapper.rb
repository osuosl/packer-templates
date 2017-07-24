#!/usr/bin/env ruby 

# wrapper script which takes a template and give us required things

# when called for running_tests, we need image_name

require 'json'
require 'optparse'
require 'csv'

fieldname = ''
parser = OptionParser.new do |opts|
  opts.banner = """
  Usage: #{0} <template_file1>...<template_fileN> -f <field_name>
  """

  opts.separator('')
  opts.on('-f F','--field_name F',"Specify a single field to extract") do |f|
    fieldname = f || ''
  end

end

params = parser.parse!
params.each do |t|
  j = JSON.load(open("#{t}"))
  
  case fieldname
    when 'image_name'
      puts "#{j['variables']['image_name']}"
    when 'output_directory'
      puts "#{j['builders'][0]['output_directory']}"
    else
      data = {}

      data['image_name'] = j['variables']['image_name']
      data['output_directory'] = j['builders'][0]['output_directory']
      csv_string = CSV.generate(force_quotes: true) do |csv|
        csv << data.values
      end
      
      puts csv_string
  end
end
