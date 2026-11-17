# The bundled Ruby must not inherit Ruby libraries managed by RVM on the host.
# This file is loaded by setup.sh through RUBYOPT before the game starts.
$LOAD_PATH.delete_if { |path| path.start_with?('/home/palbolsky/.rvm') }
