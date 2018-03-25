#! /usr/bin/env ruby

require 'aws-sdk-rds'
require_relative 'aws_prices'
require 'csv'


region_map = {
  "ap-northeast-1": "Asia Pacific (Tokyo)",
  "ap-northeast-2": "Asia Pacific (Seoul)",
  "ap-south-1": "Asia Pacific (Mumbai)",
  "ap-southeast-1": "Asia Pacific (Singapore)",
  "ap-southeast-2": "Asia Pacific (Sydney)",
  "ca-central-1": "Canada (Central)",
  "eu-central-1": "EU (Frankfurt)",
  "eu-west-1": "EU (Ireland)",
  "eu-west-2": "EU (London)",
  "sa-east-1": "South America (Sao Paulo)",
  "us-east-1": "US East (N. Virginia)",
  "us-east-2": "US East (Ohio)",
  "us-west-1": "US West (N. California)",
  "us-west-2": "US West (Oregon)",
}
data_with_regions = {}
price_data = {}
region_map.keys.each do |region|
  service = Aws::RDS::Resource.new(region: region.to_s)
  client = service.client
  dbs = []
  resp = client.describe_db_instances()
  resp.db_instances.each do |db|
    db_info = {}
    db_info[:name] = db.db_instance_identifier
    db_info[:class] = db.db_instance_class
    db_info[:storage_type] = db.storage_type
    db_info[:iops] = db.iops || 0
    db_info[:volume_encrypted] = db.storage_encrypted
    db_info[:db_type] = db.engine
    db_info[:engine_version] = db.engine_version
    db_info[:multi_az_enabled] = db.multi_az
    db_info[:availability_zone] = db.availability_zone
    db_info[:region] = region
    #will want to also get tags for RDS instances at some point
    # puts db_info
    dbs.push(db_info)
  end
  price_data[region] = {}
  multi = []
  single = []
  dbs.each do |db|
    db_class = db[:class]
    if db[:multi_az_enabled] == true
      multi.push(db_class)
    else
      single.push(db_class)
    end
  end
  multi.uniq!
  single.uniq!
  price_data[region][:multi] = multi unless multi.empty?
  price_data[region][:single] = single unless single.empty?
  data_with_regions[region.to_sym] = dbs
end

AZ_MAPPING = {
  true: "multi",
  false: "single"
}
pd = price_data.delete_if {|_, value| value.empty? }
prices = rds_prices(pd)
data_with_regions.each do |region, instance_info|
  instance_info.each_with_index do |instance, index|
    az = AZ_MAPPING[instance[:multi_az_enabled].to_s.to_sym].to_sym
    price_hash = prices[region.to_sym][az][instance[:class].to_sym]
    instance_info[index] = instance.merge(price_hash)
  end
end


h = data_with_regions.values.flatten
puts h
CSV.open('rds.tsv', "wb", {:col_sep => "\t"}) do |csv|
  csv << h[0].keys
  h.each do |elem|
    csv << elem.values
  end
end

