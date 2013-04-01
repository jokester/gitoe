# rack app for repos
require "gitoe"
require "gitoe/repo/rugged"
require "sinatra"
require "json"

module Gitoe::HTTPServer
  class Repos < ::Sinatra::Base

    Repo = ::Gitoe::Repo::Rugged_with_cache

    set :environment, :production

    def json reply
      content_type 'application/json'
      reply[:succeed] = true if reply.is_a? Hash and not reply.has_key? :succeed
      reply.to_json
    end

    error do
      json \
        :succeed => false,
        :error_message => env['sinatra.error'],
        :trace   => env['sinatra.error'].backtrace
    end

    # index
    get "/" do
      json :index => Repo.instances[:by_arg]
    end

    # create
    post "/new" do
      # create instance if not existing
      # and return id
      path = params["path"] or raise "path not specified"
      json :id => Repo.id_for(path)
    end

    # show
    get "/:repo_id/?" do
      repo = Repo.find params["repo_id"]
      json :status => repo.status
    end

    # sub namespace
    # get "/:repo_id/:resource_type/?:resource_id?" do
    Resources = Set[ 'commits' ].freeze
    get "/:repo_id/**" do
      repo = Repo.find( params["repo_id"] )
      resource,arg = params[:splat].last.split('/',2)
      # /0/commits/aaaaaaa/b/c/d
      # => {
      #   repo_id: "0",
      #   resource: "commits"
      #   arg: "aaaaaaa/b/c/d"
      # }
      raise "invalid resource type" unless Resources.include? resource
      json resource => repo.send(resource.to_sym, arg)
    end

  end
end
