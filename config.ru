require './secrets' unless ENV['RACK_ENV'] == "production"
require './app'
run Sinatra::Application
