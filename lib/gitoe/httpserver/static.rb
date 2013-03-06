# rack app for static files
require "gitoe"
require "sinatra"

module Gitoe::HTTPServer
  class Static < ::Sinatra::Base

    set :app_file, __FILE__
    set :environment, :production
    set :static_cache_control, [:public, max_age: 3600]

    get "/" do
      send_file File.join( settings.public_folder, "index.html" )
    end

  end
end
