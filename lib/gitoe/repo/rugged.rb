# repo using rugged ( https://github.com/libgit2/rugged )
require "gitoe/repo/repo"
require "rugged"

module Gitoe::Repo
  class Rugged_no_cache

    include ::Rugged
    extend Query

    def initialize path
      @rugged = Repository.new path
    end

    def path
      @rugged.path
    end

    Resources = Set[ 'commit', 'ref' ]
    def resource(res_type, res_id)
      raise "invalid resource type" unless Resources.include? res_type
      send( res_type.to_sym, res_id )
    end

    def commit sha1
      commit = @rugged.lookup(sha1)
      raise "not a commit" unless commit.is_a? Commit
      {
        :sha1    => commit.oid,
        :parents => commit.parents.map(&:oid),
      }
    end

    def ref_names
      @rugged.refs.to_a.each do |ref_name|
        ref_name.sub! %r{^/}, ""
      end << "HEAD"
    end

    def refs
      refs = {}
      ref_names.each do |ref_name|
        refs[ref_name] = ref(ref_name)
      end
      refs
    end

    def ref name
      resolved = Reference.lookup(@rugged, name)
      {
        :name   => resolved.name     ,
        :target => resolved.target   ,
        :type   => resolved.type     ,
        :log    => reflog( resolved ),
      }
    end

    def reflog ref
      raise "demand Reference" unless ref.is_a? Reference
      ref.log.each do |change|
        change[:committer][:time] = change[:committer][:time].to_i # seconds from epoch
      end
    rescue
      []
    end

  end

  class Rugged < Rugged_no_cache
    include Cache
  end
end
