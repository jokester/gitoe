#!/usr/bin/ruby
ENV['RACK_ENV'] = 'development'
require "gitoe/repo/rugged"
require "pp"

include Gitoe::Repo
i = Rugged_with_cache.new "/home/mono/rails"
pp i.instance_eval { @cached_commits.size / 2 }
