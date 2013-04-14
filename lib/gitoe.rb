require "gitoe/version"

start = Time.now

$gitoe_debug = (ENV['RACK_ENV'] == 'development')
$gitoe_log = lambda do |str|
  if $gitoe_debug
    $stderr.puts "#{ Time.now - start }s : #{str}"
    true
  else
    false
  end
end

module Gitoe
end
