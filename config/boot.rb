ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.

files = ["./.rails_env.rb", "../.rails_env.rb"]
files.each do |base|
  file = File.expand_path(base, Dir.pwd)
  require file if File.exists?(file)
end
