#!/bin/bash
# Source this file, as with the legacy ruby-dist/setup.sh.
_psdk_ruby_root="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
export PATH="$_psdk_ruby_root/bin:$PATH"
unset GEM_HOME GEM_PATH
export RUBYLIB="$_psdk_ruby_root/lib"
export RUBYOPT='--encoding utf-8:utf-8 -rclean_load_path'
unset _psdk_ruby_root
