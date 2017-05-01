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

      updater = KittehCategoryUpdater.new
      updater.read_csv(params)
      updater.update

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

class KittehCategoryUpdater
  def initialize
    @csv_data = {}
  end

  def read_csv(params)
    csv = CSV.parse(params[:file][:tempfile])
    csv.shift
    csv.each do |row|
      @csv_data[row[0]] = row
    end
  end

  def update
    @csv_data.each do |id, category|
      transformer = KittehCategoryTransformer.new(category)
      transformed_category = transformer.transform

      begin
        if id.nil?
          Bigcommerce::Category.create(transformed_category)
        else
          Bigcommerce::Category.update(id, transformed_category)
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

class KittehCategoryTransformer
  def initialize(category)
    @category = category
  end

  def transform
    {
      parent_id: @category[1],
      name: @category[2],
      description: @category[3] || '',
      sort_order: @category[4] || 0,
      page_title: @category[5] || '',
      meta_keywords: @category[6] || '',
      meta_description: @category[7] || '',
      layout_file: @category[8] || '',
      image_file: @category[10] || '',
      is_visible: @category[11] == 'true' ? true : false,
      search_keywords: @category[12] || '',
      url: @category[13]
    }
  end
end
