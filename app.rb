require 'bundler'
require 'dotenv'
require 'csv'

Bundler.require
Dotenv.load

Bigcommerce.configure do |config|
  config.auth = 'legacy'
  config.url = 'https://jay.bigcommerce.support/api/v2'
  config.username = ENV['USERNAME']
  config.api_key = ENV['API_KEY']
end

class Kitteh
  def self.column_headers
    Bigcommerce::Category.all.first.keys.map {|key| key.to_s }
  end
end

CSV.open('testsub1.csv', 'a') {|csv| csv << Kitteh.column_headers }

Bigcommerce::Category.all.each do |cat|
  puts cat.name
#  CSV.open('testsub1.csv', 'a') do |csv|
#    csv << values
#  end
    

end
