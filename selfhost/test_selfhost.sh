#!/bin/bash

set -o nounset

print_this_dir() {
  local real_path="$(readlink --canonicalize "$0")"
  (
    cd "$(dirname "$real_path")"
    pwd
  )
}

test_selfhost() {
  local name="$1"
  ../pricc ${name}.pric > ${TEMP_DIR}/${name}_gen1.exe.txt
  ./pricc  ${name}.pric > ${TEMP_DIR}/${name}_gen2.exe.txt

  diff -u \
    ${TEMP_DIR}/${name}_gen1.exe.txt \
    ${TEMP_DIR}/${name}_gen2.exe.txt
}

__DIR__="$(print_this_dir)"
TEMP_DIR="${__DIR__}/tmp"

mkdir -p tmp exe
rake build-all

test_selfhost lexer
test_selfhost parser
test_selfhost codegen
