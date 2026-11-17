# Retain the legacy require target. Ruby is built with --enable-load-relative,
# so its standard library and bundled gems already resolve inside ruby-dist.
# setup.sh resets RUBYLIB/GEM_HOME/GEM_PATH to exclude host Ruby installations.
