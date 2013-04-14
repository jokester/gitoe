# repo using rugged ( https://github.com/libgit2/rugged )
require "gitoe/repo/repo"
require "rugged"

module Gitoe::Repo
  class Rugged_backend

    # implements
    #   path       :: -> String
    #   commit     :: sha1::String -> { prop:val }
    #   refs       :: -> { ref_name : reflogs }
    #   ref        :: String -> reflogs

    # private
    #   ref_names  :: -> [ String ]
    #   reflog     :: String -> [ {} ]

    include ::Rugged

    def initialize path
      @rugged = Repository.new path
    end

    def path
      @rugged.path
    end

    def commit sha1
      # $gitoe_log[ "query #{sha1}" ]
      obj = @rugged.lookup(sha1)
      case obj
      when Commit
        commit_to_hash obj
      when Tag
        tag_to_hash obj
      else
        raise "#{obj} is not commit"
      end
    end

    def refs
      Hash[
        ref_names.map do |ref_name|
          [ ref_name, ref(ref_name) ]
        end
      ]
    end

    def ref(name)
      resolved = Reference.lookup(@rugged, name)
      basic = {
          :name   => resolved.name     ,
          :target => resolved.target   ,
          :type   => resolved.type     ,
          :log    => reflog( resolved ),
        }
      case name
      when %r{^refs/remotes/}, %r{^refs/heads/}, 'HEAD'
        extra = {}
      when %r{^refs/tags/}
        extra = deref_tag(resolved)
      else
        raise "error parsing ref <ref>"
      end
      basic.merge(extra).freeze
    end

    private

    def ref_names
      @rugged.refs.to_a.each do |ref_name|
        ref_name.sub! %r{^/} , ""
      end << "HEAD"
    end

    def deref_tag tag
      target = @rugged.lookup(tag.target)
      case target
      when Tag
        {
          tag_type: 'annotated',
          real_target: target.target.oid
        }
      when Commit
        {
          tag_type: 'lightweight'
        }
      else
        raise "don't know #{tag}"
      end
    end

    def reflog ref
      raise "demand Reference" unless ref.is_a? Reference
      log =
        begin
          ref.log
        rescue
          []
        end
      log.each do |change|
        change[:committer][:time] = change[:committer][:time].to_i # seconds from epoch
      end
    end

    def commit_to_hash commit_obj
      {
        :sha1    => commit_obj.oid,
        :parents => commit_obj.parents.map(&:oid),
        :type    => :commit
        # :author  => commit_obj.author,
        # :committer => commit_obj.committer
      }.freeze
    end

    def tag_to_hash tag_obj
      {
        :sha1    => tag_obj.oid,
        :parents => [tag_obj.target.oid],
        :type    => :annotated_tag
        # :tagger  => tag_obj.tagger
      }.freeze
    end
  end

  class RestfulRugged < Rugged_backend
    extend Query
    include Cache
    include RestfulRepo
    # ancestors: [RestfulRugged, RestfulRepo, Cache, Rugged_backend]
  end
end
