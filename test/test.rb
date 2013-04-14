#!/usr/bin/ruby
ENV['RACK_ENV'] = 'development'
require "gitoe/repo/rugged"
require "pp"

include Gitoe::Repo
i = RestfulRugged.new "/home/mono/rails"
pp i.status
