require 'rubygems'
require 'bundler'

Bundler.require

configure do
  $redis = Redis.new(url: ENV["REDIS_URL"])
end

require './app'

run KittehCat::App
