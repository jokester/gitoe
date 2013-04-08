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
      raise NotImplementedError # TODO
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
    # public methods:
    #   #status()
    #   #commits(range)

    def initialize *args
      super(*args)
      init_cache
      refresh_cache
    end

    def status
      {
        :refs     => refs         , # this refreshes cache
        :commits  => size_of_cache, # num
        :path     => path         ,
      }
    end

    def commits query_string=nil
      # return { order: content }
      # order(parent_commit) < order(child_commit)
      if query_string and query_string.size>0
        range = Range.new( * query_string.split('..').map(&:to_i) )
        cached_commits range
      else
        cached_commits
      end
    end

    def ref name
      # update cache in superclass#refs
      ret = super
      ret[:log].each do |log|
        commit log[:oid_new]
        [ :oid_old, :oid_new ].each do|key|
          sha1 = log[key]
          next if in_cache? sha1
          next if sha1=="0000000000000000000000000000000000000000"
          commit sha1
        end
      end
      ret
    end

    def commit sha1
      # if in_cache?
      #   just take from cache
      # else
      #   add to cache, after adding all its ancestors to cache
      if in_cache? sha1
        return from_cache sha1
      end
      this = super
      queried = { this[:sha1] => this }
      # Hash became ordered in ruby1.9
      # ref: http://www.igvita.com/2009/02/04/ruby-19-internals-ordered-hash/
      not_cached_commits = this[:parents].dup
      while not_cached_commits.size > 0
        # traverse DAG to get ancestors, closest ancestors first
        ancestor_sha1 = not_cached_commits.shift
        next if queried.has_key? ancestor_sha1
        next if in_cache? ancestor_sha1
        ancestor = super(ancestor_sha1)
        queried[ ancestor_sha1 ] = ancestor
        ancestor[:parents].each do |grand_sha1|
          not_cached_commits.push grand_sha1
        end
      end
      # add to cache
      queried.keys.reverse.each do |commit_sha1|
        add_to_cache(commit_sha1 , queried[commit_sha1])
      end
      this
    end

    private
    def refresh_cache
      refs
    end

    def add_to_cache sha1, content
      raise "#{sha1} already in cache" if in_cache? sha1
      new_id = size_of_cache
      @cached_commits[sha1] = content
      @cached_commits[new_id] = content
    end

    def init_cache
      @cached_commits = {} # { sha1:content, order:content }
    end

    def size_of_cache
      Integer( @cached_commits.size / 2 )
    end

    def from_cache sha1
      @cached_commits[sha1] or raise "not in cache"
    end

    def in_cache? key
      case key
      when String, Fixnum
        @cached_commits.has_key? key
      else
        raise "String or Fixnum expected"
      end
    end

    def cached_commits range=nil
      case range
      when Range
        @cached_commits.select{|key| range.include? key }
      else
        @cached_commits.select{|key| key.is_a? Fixnum }
      end
    end
  end
end
