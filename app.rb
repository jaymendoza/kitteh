require 'bundler'
require 'dotenv'
require 'csv'

Bundler.require
Dotenv.load

module KittehCat
  class App < Sinatra::Application
    get '/' do
      erb :index
    end

    post '/csv/generate' do
      content_type 'application/csv'
      attachment 'foo.csv'
      ### TODO: generate file name with timestamp, e.g. categories-2017-04-26.csv

      Utils.authenticate(params)
      KittehCSV.generate
    end

    post '/upload' do
      file = params[:file][:tempfile]
      csv_data = {}
      csv = CSV.parse(file)
      csv.shift

      csv.each do |row|
        csv_data[row[0]] = row
      end

      Utils.authenticate(params)
      Kitteh.update_categories(csv_data)
      'Categories Updated'
    end
  end

  class Utils
    def self.authenticate(params)
      return false if params[:url].nil? || params[:username].nil? || params[:api_key].nil?
      Bigcommerce.configure do |config|
        config.auth = 'legacy'
        config.url = params[:url]
        config.username = params[:username]
        config.api_key = params[:api_key]
        config.ssl = { :verify => false }
      end
    end
  end
end

class KittehCSV
  def self.column_headers
    Bigcommerce::Category.all.first.keys.map {|key| key.to_s }
  end

  def self.generate
    CSV.generate do |csv|
      csv << column_headers
      Bigcommerce::Category.all.each do |category|
        csv << category.values
      end
    end
  end
end

class Kitteh
  def self.categories
    ### TODO: paginate here
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
      description: array[3] || '',
      sort_order: array[4],
      page_title: array[5] || '',
      meta_keywords: array[6] || '',
      meta_description: array[7] || '',
      layout_file: array[8],
      image_file: array[10] || '',
      is_visible: array[11] == 'true' ? true : false,
      search_keywords: array[12] || '',
      url: array[13]
    }
  end
end
