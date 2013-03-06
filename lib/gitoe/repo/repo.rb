require "gitoe"

module Gitoe::Repo

  # instance methods, enable querying of instances
  module Query

    def instances
      @instances ||= {
        :by_arg => {}, # arg => id
        :by_id  => {}, # id  => instance
      }
    end

    def create arg
      id  = instances[:by_id].size
      instances[:by_id][id] = self.new arg
      instances[:by_arg][arg] = id
    end

    def destroy id
      # TODO
    end

    def find id
      id = Integer(id) unless id.is_a? Integer
      instances[:by_id][id] or raise "repo not found"
    end

    def id_for arg
      existing = instances[:by_arg][arg]
      if existing
        existing
      else
        create arg
      end
    end

  end

  module Cache
    def initialize *args
      super(*args)
      @cached_commits = {}
      clone
    end

    def clone
      {
        :commits  => commits ,
        :path     => path    ,
        :refs     => refs    ,
      }
    end

    def commits
      @cached_commits
    end

    def ref name
      return refs if name.nil? or name.empty?
      ret = super
      ret[:log].each do |log|
        commit log[:oid_new]
        [ :oid_old, :oid_new ].each do|key|
          sha1 = log[key]
          commit sha1 unless sha1=="0000000000000000000000000000000000000000"
        end
      end
      ret
    end

    def commit sha1
      return @cached_commits[sha1] if(@cached_commits.has_key? sha1)
      return commits if sha1.nil? or sha1.empty?

      this = super
      not_in_cache = this[:parents].dup

      while not_in_cache.size > 0 do
        head_sha1 = not_in_cache.shift
        if @cached_commits.has_key? head_sha1
          # do nothing
        else
          head = super( head_sha1 )
          head.delete :sha1
          @cached_commits[ head_sha1 ] = head
          head[:parents].each do |parent_sha1|
            not_in_cache.push(parent_sha1) unless @cached_commits.has_key? parent_sha1
          end
        end
      end

      @cached_commits[this[:sha1]] = this
    end
  end

end
