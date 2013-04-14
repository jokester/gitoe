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
      #   add sha1 and all its ancestors to cache, in topological order
      if in_cache? sha1
        return from_cache sha1
      end
      this = super.freeze
      if in_cache? this[:sha1]
        return this
      end

      # Hash became ordered in ruby1.9
      # ref: http://www.igvita.com/2009/02/04/ruby-19-internals-ordered-hash/
      queried = { this[:sha1] => this }
      to_query = this[:parents].dup


      while to_query.size > 0
        start = to_query.first
        to_query.delete start

        next if queried.has_key?(start) or in_cache?(start)

        parent = super start
        queried[ start ] ||= parent
        parent[:parents].each do |p|
          next if queried.has_key? p
          next if in_cache? p
          to_query.push p
        end

      end
      $gitoe_log[ "gathered #{queried.size} from #{sha1}" ]

      # add to cache
      sort_topo(queried).each do |s|
        add_to_cache s, queried[s]
      end

      this
    end

    private
    def refresh_cache
      refs
    end

    def add_to_cache sha1, content
      if $gitoe_debug
        raise "#{sha1} already in cache" if in_cache? sha1
        content[:parents].each do |parent_sha1|
          raise "parent of #{sha1} : #{parent_sha1} not found" if not in_cache? parent_sha1
        end
      end
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

    def sort_topo queried

      sorted = []

      in_degree = Hash.new{|h,k| h[k] = 0 }
      children = Hash.new{|h,k| h[k] = [] }

      queried.each do |sha1,content|
        in_degree[sha1]
        content[:parents].each do |p|
          in_degree[p]
          in_degree[sha1] += 1
          children[p] << sha1
        end
      end

      to_remove = in_degree.keys.select{|k| in_degree[k] == 0 }
      while to_remove.size > 0
        # $gitoe_log[ "topo-sorting : remaining #{in_degree.size}" ]

        n = to_remove.shift
        sorted.push n
        in_degree.delete n

        children[n].each do |c|
          new_in_degree = in_degree[c] -= 1
          to_remove.push c if new_in_degree == 0
        end
      end

      $gitoe_log[ "topo-sorting DONE" ]
      return sorted.select{|s| queried.has_key? s }
    end
  end
end
