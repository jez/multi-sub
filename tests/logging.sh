#!/usr/bin/env bash

red=$'\x1b[0;31m'
green=$'\x1b[0;32m'
yellow=$'\x1b[0;33m'
cyan=$'\x1b[0;36m'
cnone=$'\x1b[0m'

if [ -t 2 ]; then
  USE_COLOR=1
else
  USE_COLOR=0
fi

# Detects whether we can add colors or not
in_color() {
  local color="$1"
  shift

  if [ "$USE_COLOR" = "1" ]; then
    echo "$color$*$cnone"
  else
    echo "$*"
  fi
}

success() { echo "$(in_color "$green" "[ OK ]") $*" >&2; }
error()   { echo "$(in_color "$red"   "[ERR!]") $*" >&2; }
info()    { echo "$(in_color "$cyan"  "[ .. ]") $*" >&2; }
# Color entire warning to get users' attention (because we won't stop).
attn()    { in_color "$yellow" "[WARN] $*" >&2; }

fatal() {
  error "$@"
  exit 1
}

travis_fold_start() {
  local fold_name="$1"
  local fold_msg="$2"
  echo "travis_fold:start:$fold_name"
  info "$fold_msg"
}

travis_fold_end() {
  local fold_name="$1"
  echo "travis_fold:end:$fold_name"
}
