require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new do |t|
  t.pattern = "test/test*.rb"
end

desc "gitoe (development)"
task :run do
  ENV["RACK_ENV"] = "development"
  sh "bundle exec gitoe"
end

desc "gitoe (production)"
task :production do
  ENV["RACK_ENV"] = "production"
  sh "bundle exec gitoe"
end

desc "watch and re-compile with guard"
task :watch do
  sh "bundle exec guard"
end

desc "compile with nanoc"
task :compile do
  sh "bundle exec nanoc"
end

task :default => :run
