# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'gitoe/version'

Gem::Specification.new do |gem|
  gem.name          = "gitoe"
  gem.version       = Gitoe::VERSION
  gem.authors       = ["Wang Guan"]
  gem.email         = ["momocraft@gmail.com"]
  gem.description   = %q{visualize local git activities}
  gem.summary       = %q{visualize local git activities}
  gem.homepage      = "https://github.com/jokester/gitoe"

  gem.files         = `git ls-files`.split($/).select {|fn| File.file? fn }
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_runtime_dependency "rugged"       # git
  gem.add_runtime_dependency "sinatra"      # web server
  gem.add_runtime_dependency "activesupport"# JSON encoding

  gem.add_development_dependency "nanoc", ">= 3.6.3"
  gem.add_development_dependency "haml"
  gem.add_development_dependency "sass"
  gem.add_development_dependency "coffee-script"

  gem.add_development_dependency "thin"
  gem.add_development_dependency "guard"
  gem.add_development_dependency "guard-nanoc"

  gem.add_development_dependency "pry"
end
