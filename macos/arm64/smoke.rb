ENV['PSDK_TEST_PLATFORM'] = 'macos'
load File.expand_path('lib/psdk-runtime/runtime-functional.rb', Dir.pwd)
File.write('smoke-passed', "passed\n")
