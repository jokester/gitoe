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
      #$stderr.write "actually looked up sha1=#{sha1}\n"
      commit_obj = @rugged.lookup(sha1)
      raise "not a commit" unless commit_obj.is_a? Commit
      {
        :sha1    => commit_obj.oid,
        :parents => commit_obj.parents.map(&:oid),
      }.freeze
    end

    def refs
      ret = {}
      ref_names.each do |ref_name|
        ret[ref_name] = ref(ref_name)
      end
      ret
    end

    def ref(name)
      resolved = Reference.lookup(@rugged, name)
      {
        :name   => resolved.name     ,
        :target => resolved.target   ,
        :type   => resolved.type     ,
        :log    => reflog( resolved ),
      }
    end

    private

    def ref_names
      @rugged.refs.to_a.each do |ref_name|
        ref_name.sub! %r{^/} , ""
      end << "HEAD"
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

  end

  class Rugged_with_cache < Rugged_backend
    extend Query
    include Cache
    # ancestors: [Rugged_with_cache, Cache, Rugged_backend]
  end
end
