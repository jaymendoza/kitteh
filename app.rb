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

  def self.categories
    # paginate here
  end

  def self.write_csv
    CSV.open('testsub1.csv', 'a') {|csv| csv << column_headers }

    Bigcommerce::Category.all.each do |category|
      CSV.open('testsub1.csv', 'a') do |csv|
        csv << category.values
      end
    end
  end

  def self.read_csv
    csv_data = {}
    csv = CSV.read('testsub1.csv')
    csv.shift

    csv.each do |row|
      csv_data[row[0]] = row
    end

    csv_data
  end
end

#Kitteh.write_csv
puts Kitteh.read_csv
