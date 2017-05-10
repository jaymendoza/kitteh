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
      updater.update(params)

      'Categories Updated'
    end
  end

  class Utils
    def self.authenticate(params)
      return false if params['url'].nil? || params['username'].nil? || params['api_key'].nil?
      Bigcommerce.configure do |config|
        config.auth = 'legacy'
        config.url = params['url']
        config.username = params['username']
        config.api_key = params['api_key']
        config.ssl = { :verify => false }
      end
    end
  end
end

class KittehCategoryUpdater
  def initialize
    @csv = []
  end

  def read_csv(params)
    @csv = CSV.parse(params[:file][:tempfile], encoding: "ISO8859-1:utf-8", headers: true)
  end

  def update(params)
    @csv.each do |category|
      transformer = KittehCategoryTransformer.new(category)
      transformed_category = transformer.transform

      begin
        if transformed_category.key?(:id)
          id = transformed_category[:id]
          Resque.enqueue(KittehCategoryUpdater, id, transformed_category, params)
        else
          Resque.enqueue(KittehCategoryCreator, transformed_category, params)
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
    cat = {
      id: get_id(@category.fetch('id')),
      parent_id: get_parent_id(@category.fetch('parent_id')),
      name: get_name(@category.fetch('name')),
      description: get_description(@category.fetch('description')),
      sort_order: get_sort_order(@category.fetch('sort_order')),
      page_title: get_page_title(@category.fetch('page_title')),
      meta_keywords: get_meta_keywords(@category.fetch('meta_keywords')),
      meta_description: get_meta_description(@category.fetch('meta_description')),
      layout_file: get_layout_file(@category.fetch('layout_file')),
      image_file: get_image_file(@category.fetch('image_file')),
      is_visible: get_is_visible(@category.fetch('is_visible')),
      search_keywords: get_search_keywords(@category.fetch('search_keywords')),
      url: get_url(@category.fetch('url'))
    }

    cat.delete_if {|k,v| v.nil? }
  end

  def get_id(id)
    return nil if id.nil?
    id
  end

  def get_parent_id(parent_id)
    if parent_id.nil?
      raise Exception, 'Category must have Parent ID'
    else
      parent_id
    end
  end

  def get_name(name)
    if name.nil?
      raise Exception, 'Category must have a name'
    else
      name.force_encoding('UTF-8')
    end
  end

  def get_description(description)
    return '' if description.nil?
    description.force_encoding('UTF-8')
  end

  def get_sort_order(sort_order)
    return '0' if sort_order.nil?
    sort_order
  end

  def get_page_title(page_title)
    return '' if page_title.nil?
    page_title.force_encoding('UTF-8')
  end

  def get_meta_keywords(meta_keywords)
    return '' if meta_keywords.nil?
    meta_keywords.force_encoding('UTF-8')
  end

  def get_meta_description(meta_description)
    return '' if meta_description.nil?
    meta_description.force_encoding('UTF-8')
  end

  def get_layout_file(layout_file)
    return '' if layout_file.nil?
    layout_file.force_encoding('UTF-8')
  end

  def get_image_file(image_file)
    return '' if image_file.nil?
    image_file.force_encoding('UTF-8')
  end

  def get_is_visible(is_visible)
    is_visible === 'true' ? true : false
  end

  def get_search_keywords(search_keywords)
    return '' if search_keywords.nil?
    search_keywords.force_encoding('UTF-8')
  end

  def get_url(url)
    return nil if url.nil?
    url.force_encoding('UTF-8')
  end
end

class KittehCategoryCreator
  @queue = 'create'

  def self.perform(category, params)
    KittehCat::Utils.authenticate(params)
    Bigcommerce::Category.create(category)
  end
end

class KittehCategoryUpdater
  @queue = 'update'

  def self.perform(id, category, params)
    KittehCat::Utils.authenticate(params)
    Bigcommerce::Category.update(id, category)
  end
end

