require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new do |t|
  t.pattern = "test/test*.rb"
end

desc "gitoe"
task :run do
  ENV["RACK_ENV"] = "development"
  sh "bundle exec gitoe"
end

task :test do
  ENV["RACK_ENV"] = "development"
  sh "bundle exec test/test.rb"
end

desc "nanoc watch"
task :watch do
  sh "bundle exec nanoc watch"
end

desc "nanoc compile"
task :compile do
  sh "bundle exec nanoc"
end

task :default => :run
