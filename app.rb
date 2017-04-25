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

  def self.update_categories(category_data)
    category_data.each do |id, data|
      category_hash = transform_category_data(data)

      begin
        Bigcommerce::Category.update(id, category_hash)
      rescue Bigcommerce::ResourceConflict => e
          puts e.message
          puts 'cat id: ' + id
          puts category_hash
      end
    end
  end

  def self.transform_category_data(array)
    {
      parent_id: array[1],
      name: array[2],
      description: array[3],
      sort_order: array[4],
      page_title: array[5],
      meta_keywords: array[6],
      meta_description: array[7],
      layout_file: array[8],
      image_file: array[10],
      is_visible: array[11] == 'true' ? true : false,
      search_keywords: array[12],
      url: array[13]
    }
  end
end

#Kitteh.write_csv
d = Kitteh.read_csv
Kitteh.update_categories(d)
