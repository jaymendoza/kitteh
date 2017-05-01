require 'bundler'
require 'csv'

Bundler.require

module KittehCat
  class App < Sinatra::Application
    get '/' do
      erb :index
    end

    post '/csv/generate' do
      Utils.authenticate(params)
      filename = "categories-#{Time.now.strftime('%F')}-#{Time.now.to_i.to_s}.csv"

      content_type 'application/csv'
      attachment filename

      builder = KittehCSVBuilder.new
      builder.get_categories
      builder.build_csv
    end

    post '/upload' do
      Utils.authenticate(params)

      csv_data = KittehCSV.prepare(params)
      KittehCategories.update_categories(csv_data)
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
  def self.prepare(params)
    csv_data = {}
    csv = CSV.parse(params[:file][:tempfile])
    csv.shift

    csv.each do |row|
      csv_data[row[0]] = row
    end
    csv_data
  end
end

class KittehCSVBuilder
  attr_reader :categories

  def initialize
    @categories = []
  end

  def build_csv
    CSV.generate do |csv|
      csv << column_headers
      @categories.each do |category|
        csv << category.values
      end
    end
  end

  def column_headers
    @categories.first.keys.map {|key| key.to_s }
  end

  def get_categories
    number_of_pages = (Bigcommerce::Category.count[:count].to_f / 250).ceil

    for page in 1..number_of_pages
      Bigcommerce::Category.all(page: page, limit: 250).each do |category|
        @categories << category
      end
    end
  end
end

class KittehCategories
  def self.update_categories(category_data)
    category_data.each do |id, data|
      category_hash = transform_category_data(data)

      begin
        if id.nil?
          Bigcommerce::Category.create(category_hash)
        else
          Bigcommerce::Category.update(id, category_hash)
        end
      rescue Bigcommerce::ResourceConflict => e
        puts e.message
        puts 'cat id: ' + id
        puts category_hash
      rescue Bigcommerce::NotFound => e
        puts e.message
        puts 'cat id: ' + id
        puts category_hash
      end
    end
  end

  ### TODO: reconsider validation
  def self.transform_category_data(array)
    {
      parent_id: array[1],
      name: array[2],
      description: array[3] || '',
      sort_order: array[4] || 0,
      page_title: array[5] || '',
      meta_keywords: array[6] || '',
      meta_description: array[7] || '',
      layout_file: array[8] || '',
      image_file: array[10] || '',
      is_visible: array[11] == 'true' ? true : false,
      search_keywords: array[12] || '',
      url: array[13]
    }
  end
end
