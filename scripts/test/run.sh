#!/bin/sh
set -eu

cd /workspace

eval "$(luarocks --tree /workspace/lua_modules path)"
export PATH="/workspace/lua_modules/bin:$PATH"

if [ -n "${TEST_FILE:-}" ]; then
  busted "$TEST_FILE"
else
  busted
fi
