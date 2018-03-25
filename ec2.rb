#! /usr/bin/env ruby

require 'aws-sdk-ec2'
require_relative './aws_prices.rb'
require 'csv'


classes_w_region = {}
data_with_regions = {}

def get_tag_value(tag_array,name)
  tag_array.each do |tag|
    if tag.key.downcase == name.downcase
      return tag.value
    end
  end
  return 'N/A'
end

REGION_MAP.keys.each do |region|
  service = Aws::EC2::Resource.new(region: region.to_s)
  client = service.client
  instances = client.describe_instances()
  instance_group = []
  instances.reservations.each do |i|
    instance = i.instances[0]
    instance_info = {}
    instance_info[:name] = get_tag_value(instance.tags,'name')
    instance_info[:product] = get_tag_value(instance.tags,'product')
    instance_info[:landscape] = get_tag_value(instance.tags,'landscape')
    instance_info[:environment] = get_tag_value(instance.tags,'environment')
    instance_info[:class] = instance.instance_type
    instance_info[:instance_id] = instance.instance_id
    instance_info[:state] = i.instances[0].state.name
    instance_info[:availability_zone] = instance.placement.availability_zone
    instance_group.push(instance_info)
  end
  classes = instance_group.map {|x| x[:class]}
  classes_w_region[region.to_sym] = classes.uniq
  data_with_regions[region.to_sym] = instance_group
end

classes_w_region.delete_if {|k,v| v.empty?}
price_info = ec2_prices(classes_w_region)
data_with_regions.each do |region,instance_info|
  instance_info.each_with_index do |instance,index|
    instance_info[index] = instance.merge(price_info[region.to_sym][instance[:class].to_sym])
  end
end

h = data_with_regions.values.flatten #merge all arrays to single level array
puts h

#output instance details to tab seperated values file.
CSV.open('ec2.tsv', "wb", {:col_sep => "\t"}) do |csv|
  csv << h[0].keys # add headers to output file
  h.each do |elem|
    csv << elem.values
  end
end

