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

  module RestfulRepo
    # public methods( 'resources' ):
    #   #status
    #   #commits

    def status
      {
        :refs           => refs         ,
        :path           => path         ,
        :cached_commits => size_of_cache,
      }
    end

    def commits start, options={}
      # url : start to fetch
      # options :
      #   limit
      limit = (options['limit'] || 0).to_i

      this = commit start
      queried = { this[:sha1] => this }
      to_query = this[:parents].dup

      while to_query.size > 0 and queried.size < limit

        another = to_query.shift
        next if queried.has_key?(another)

        parent = commit another
        queried[ another ] ||= parent
        parent[:parents].each do |p|
          next if queried.has_key? p
          to_query.push p
        end
      end
      $gitoe_log[ "gathered #{queried.size} from #{start}" ]

      queried
    end

  end

  module Cache
    def initialize *args
      init_cache
      super
    end

    private

    def ref name
      follow_ref super
    end

    def follow_ref ref_hash
      ref_hash
    end

    def commit sha1, options={}
      # if in_cache?
      #   just take from cache
      # else
      #   add sha1 and all its ancestors to cache, in topological order
      if in_cache? sha1
        return from_cache sha1
      end
      this = super(sha1).freeze
      if not in_cache? this[:sha1]
        add_to_cache this[:sha1], this
      end
      this
    end

    private

    def add_to_cache sha1, content
      if $gitoe_debug and in_cache?(sha1)
        raise "#{sha1} already in cache"
      end
      $gitoe_log[ "add #{sha1} to cache" ]
      @cached_commits[sha1] = content
    end

    def init_cache
      @cached_commits = {} # { sha1:content, order:content }
    end

    def size_of_cache
      @cached_commits.size
    end

    def from_cache sha1
      @cached_commits[sha1] or raise "not in cache"
    end

    def in_cache? key
      @cached_commits.has_key? key
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
