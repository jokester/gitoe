require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new do |t|
  t.pattern = "test/test*.rb"
end

task :run do
  ENV["RACK_ENV"] = "development"
  sh "bundle exec gitoe"
end

task :default => :run
