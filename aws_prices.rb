#! /usr/bin/env ruby

require 'aws-sdk-pricing'

REGION_MAP = {
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
AZ_MAP = {
  "multi": "Multi-AZ",
  "single": "Single-AZ"
}
service = Aws::Pricing::Resource.new(region: 'us-east-1')
CLIENT = service.client

def ec2_prices(price_map)
  return_hash = {}
  price_map.each do |region, instance_types|
    return_hash[region.to_sym] = ec2_type_price_by_region(region,instance_types)
  end
  return_hash
end

def ec2_type_price_by_region(region, instance_types)
  prices = {}
  instance_types.each do |instance_type|
    get_products_response = CLIENT.get_products(
      {
        service_code: "AmazonEC2",
        filters: [
          {
            type: "TERM_MATCH",
            field: "instanceType",
            value: instance_type,
          },
          {
            type: "TERM_MATCH",
            field: 'operatingSystem',
            value: 'Linux',
          },
          {
            type: "TERM_MATCH",
            field: 'tenancy',
            value: 'Shared',
          },
          {
            type: "TERM_MATCH",
            field: 'location',
            value: REGION_MAP[region.to_sym],
          },
        ],
        max_results: 1,
      }
    )

    price_lists = get_products_response.data.price_list
    price_lists.each do |price_list|
      price_info = {}
      price_list_info = JSON.parse(price_list)
      costing = price_list_info["terms"]["OnDemand"].flatten[1]['priceDimensions'].flatten[1]
      price_info[:instance_type] = price_list_info['product']['attributes']['instanceType']
      price_info[:current_generation] = price_list_info['product']['attributes']['currentGeneration']
      price_info[:price] = costing['pricePerUnit']['USD'].to_f #hopefully this never strips significant data
      price_info[:price_unit] = costing['unit']
      price_info[:region] = region
      prices[price_info[:instance_type].to_sym] = price_info
    end
  end
  return prices
end

def rds_prices(price_map)
  return_hash = {}
  price_map.each do |region, rds_types|
    az_info = {}
    rds_types.each do |az,classes|
      az_info[az] = rds_type_price_by_region(region,classes,az)
    end
    return_hash[region.to_sym] = az_info
  end
  return_hash
end

def rds_type_price_by_region(region, instance_types,az)
  prices = {}
  instance_types.each do |instance_type|
    get_products_response = CLIENT.get_products(
      {
        service_code: "AmazonRDS",
        filters: [
          {
            type: "TERM_MATCH",
            field: "instanceType",
            value: instance_type,
          },
          {
            type: "TERM_MATCH",
            field: 'databaseEngine',
            value: 'mysql',
          },
          {
            type: "TERM_MATCH",
            field: 'deploymentOption',
            value: AZ_MAP[az],
          },
          {
            type: "TERM_MATCH",
            field: 'location',
            value: REGION_MAP[region.to_sym],
          },
        ],
      }
    )

    price_lists = get_products_response.data.price_list
    price_lists.each do |price_list|
      price_info = {}
      price_list_info = JSON.parse(price_list)
      costing = price_list_info["terms"]["OnDemand"].flatten[1]['priceDimensions'].flatten[1]
      price_info[:instance_type] = price_list_info['product']['attributes']['instanceType']
      price_info[:current_generation] = price_list_info['product']['attributes']['currentGeneration']
      price_info[:price] = costing['pricePerUnit']['USD'].to_f #hopefully this never strips significant data
      price_info[:price_unit] = costing['unit']
      price_info[:region] = region
      price_info[:db_type] = price_list_info['product']['attributes']['databaseEngine']
      prices[price_info[:instance_type].to_sym] = price_info
    end
  end
  return prices
end