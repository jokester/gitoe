#!/usr/bin/ruby
ENV['RACK_ENV'] = 'development'
require "gitoe/repo/rugged"
require "pp"

include Gitoe::Repo
i = RestfulRugged.new "/home/mono/config"
pp i.commits '83b7,23c7', { 'limit' => 500 }
pp i.status
