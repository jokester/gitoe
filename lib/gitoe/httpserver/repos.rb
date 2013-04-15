# rack app for repos
require "gitoe"
require "gitoe/repo/rugged"
require "sinatra"
require "json"

module Gitoe::HTTPServer
  class Repos < ::Sinatra::Base

    Repo = ::Gitoe::Repo::RestfulRugged

    set :environment, :production

    def json reply
      content_type 'application/json'
      reply.to_json
    end

    error do
      json \
        :error_message => env['sinatra.error'],
        :backtrace   => env['sinatra.error'].backtrace
    end

    # index
    get "/" do
      json Repo.instances[:by_arg]
    end

    # create
    post "/new" do
      # create instance if not existing
      # and return id
      path = params["path"] or raise "path not specified"
      repo_id = Repo.id_for(path)
      repo = Repo.find repo_id
      json \
        :id   => repo_id ,
        :path => repo.path
    end

    # show
    get "/:repo_id/?" do
      repo = Repo.find params["repo_id"]
      json repo.status
    end

    # namespace under /:repo_id/:resource
    Resources = Set[ 'commits', 'commit' ].freeze
    get "/:repo_id/**" do

      repo = Repo.find( params["repo_id"] )

      sub_str = params[:splat].last # "**" part

      resource, url = sub_str.split('/',2)
      raise "invalid resource '#{resource}'" unless Resources.include? resource
      query_hash = env['rack.request.query_hash']
      # /1/commits/aaaaaaa/b/c/d ? a=1 & b=1
      # => {
      #   repo_id: "1",
      #   resource: "commits"
      #   arg: "aaaaaaa/b/c/d"
      #   query_hash:
      # }
      # json resource => repo.send(resource.to_sym, arg, env[])
      json repo.send(resource, url, query_hash )
    end

  end
end
