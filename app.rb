require 'bundler'
require 'dotenv'

Bundler.require
Dotenv.load

Bigcommerce.configure do |config|
  config.auth = 'legacy'
  config.url = 'https://jay.bigcommerce.support/api/v2'
  config.username = ENV['USERNAME']
  config.api_key = ENV['API_KEY']
end

class OrderExporter 
  PRODUCT_FIELDS = ['name', 'sku', 'base_price']
  SHIPPING_ADDRESS_FIELDS = ['first_name']
  COUPON_FIELDS = ['code', 'amount', 'discount']

  def self.handle_subresource(sub)
    resource = sub[:resource].split('/').last
    id = sub[:resource].match(/\d+/)[0]

    case resource
    when 'products'
      build_resource_string('Product', id, PRODUCT_FIELDS)
    when 'shippingaddresses'
      build_resource_string('ShippingAddress', id, SHIPPING_ADDRESS_FIELDS)
    when 'coupons'
      build_resource_string('Coupon', id, COUPON_FIELDS)
    end
  end

  def self.build_resource_string(resource, id, fields)
    full_class_path = 'Bigcommerce::Order' + resource
    klass = Module.const_get(full_class_path)
    cell_contents = ''

    klass.all(id.to_i).each do |rsc|
      resource_string = ''
      fields.each do |field|
        if !rsc.send(field).empty?
          resource_string << "#{field}: #{rsc.send(field)}, "
        end
      end
      cell_contents << resource_string.chomp(', ') + ' -- '
    end

    cell_contents.chomp(' -- ')
  end
end

#CSV.open('testsub1.csv', 'a') {|csv| csv << Bigcommerce::Order.all.first.keys }

Bigcommerce::Category.all.each do |cat|
  puts cat.name
#  CSV.open('testsub1.csv', 'a') do |csv|
#    csv << values
#  end
    

end
