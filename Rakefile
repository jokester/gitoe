require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new do |t|
  t.pattern = "test/test*.rb"
end

desc "gitoe (development)"
task :run do
  ENV["RACK_ENV"] = "development"
  sh "bundle exec gitoe -o --port=3000"
end

desc "gitoe (production)"
task :production do
  ENV["RACK_ENV"] = "production"
  sh "bundle exec gitoe"
end

task :demo do
  ENV["RACK_ENV"] = "production"
  sh "bundle exec gitoe -o --port=12345"
end

desc "watch and re-compile with guard"
task :guard do
  sh "bundle exec guard"
end

desc "watch and re-compile with guard"
task :watch do
  sh "bundle exec nanoc watch"
end

desc "compile with nanoc"
task :compile do
  sh "bundle exec nanoc"
end

task :default => :run
