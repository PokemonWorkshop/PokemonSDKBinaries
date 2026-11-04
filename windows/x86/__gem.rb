# Compatibility entry point for the Windows launcher: the first argument is
# the launcher command ("gem"), followed by arguments for RubyGems.
require 'rubygems'
require 'rubygems/gem_runner'
require 'rubygems/exceptions'

begin
  Gem::GemRunner.new.run(ARGV.drop(1))
rescue Gem::SystemExitException => error
  exit error.exit_code
end
