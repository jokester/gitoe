#!/usr/bin/ruby
require "gitoe/repo/rugged"
require "pp"

include Gitoe::Repo
i = Rugged_with_cache.new "/home/mono/config"
c = i.commit("87445c")
pp c
pp i.instance_eval { @cached_commits }
