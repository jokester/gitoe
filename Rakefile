
desc "watch and re-compile with guard"
task :guard do
  sh "bundle exec guard"
end

desc "host compiled content with nanoc"
task :view do
  sh "bundle exec nanoc view"
end

desc "compile with nanoc"
task :compile do
  sh "bundle exec nanoc"
end

task :default => :compile
