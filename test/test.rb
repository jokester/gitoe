#!/usr/bin/ruby
require "gitoe/repo/rugged"
require "pp"

$rejected = Hash.new 0

include Gitoe::Repo
i = Rugged_with_cache.new "/home/mono/linux"
#c = i.commit("87445c")
#pp c
pp i.instance_eval { @cached_commits.size }
