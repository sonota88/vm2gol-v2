#!/bin/bash

set -o nounset
# set -o xtrace

print_this_dir() {
  local real_path="$(readlink --canonicalize "$0")"
  (
    cd "$(dirname "$real_path")"
    pwd
  )
}

__DIR__="$(print_this_dir)"
TEST_DIR="${__DIR__}/test"
TEMP_DIR="${__DIR__}/tmp"
EXE_DIR="${__DIR__}/exe"

RUBY_VER_DIR="$(
  cd $__DIR__
  cd ..
  pwd
)"

RUNNER=${RUBY_VER_DIR}/pricvm

MAX_ID_JSON=7
MAX_ID_LEX=2
MAX_ID_PARSE=2
MAX_ID_STEP=17

ERRS=""

build() {
  rake build-all
  local st=$?
  if [ $st -ne 0 ]; then
    exit $st
  fi
}

run_exe() {
  local name="$1"; shift
  local infile="$1"; shift

  cp $infile ${TEMP_DIR}/stdin
  $RUNNER ${EXE_DIR}/${name}.exe.txt
}

# --------------------------------

setup() {
  mkdir -p $TEMP_DIR
  mkdir -p $EXE_DIR
}

postproc() {
  local stage="$1"; shift

  if [ "$ERRS" = "" ]; then
    echo "${stage}: ok"
  else
    echo "----"
    echo "FAILED: ${ERRS}"
    exit 1
  fi
}

get_ids() {
  local max_id="$1"; shift

  if [ $# -eq 1 ]; then
    echo "$1"
  else
    seq 1 $max_id
  fi
}

# --------------------------------

test_json_nn() {
  local nn="$1"; shift

  echo "case ${nn}"

  local input_file="${TEST_DIR}/json/${nn}.json"
  local temp_json_file="${TEMP_DIR}/test.json"
  local exp_tokens_file="${TEST_DIR}/json/${nn}.json"

  run_exe json_tester $input_file > $temp_json_file
  if [ $? -ne 0 ]; then
    ERRS="${ERRS},${nn}_json"
    return
  fi

  ruby ${TEST_DIR}/diff.rb json $exp_tokens_file $temp_json_file
  if [ $? -ne 0 ]; then
    # meld $exp_tokens_file $temp_json_file &

    ERRS="${ERRS},json_${nn}_diff"
    return
  fi
}

test_json() {
  local ids="$(get_ids $MAX_ID_JSON "$@")"

  for id in $ids; do
    test_json_nn $(printf "%02d" $id)
  done
}

# --------------------------------

test_lex_nn() {
  local nn="$1"; shift

  echo "case ${nn}"

  local input_file="${TEST_DIR}/lex/${nn}.vg.txt"
  local temp_tokens_file="${TEMP_DIR}/test.tokens.txt"
  local exp_tokens_file="${TEST_DIR}/lex/exp_${nn}.txt"

  run_exe lexer $input_file > $temp_tokens_file
  if [ $? -ne 0 ]; then
    ERRS="${ERRS},${nn}_lex"
    return
  fi

  ruby ${TEST_DIR}/diff.rb text $exp_tokens_file $temp_tokens_file
  if [ $? -ne 0 ]; then
    # meld $exp_tokens_file $temp_tokens_file &

    ERRS="${ERRS},lex_${nn}_diff"
    return
  fi
}

test_lex() {
  local ids="$(get_ids $MAX_ID_LEX "$@")"

  for id in $ids; do
    test_lex_nn $(printf "%02d" $id)
  done
}

# --------------------------------

test_parse_nn() {
  local nn="$1"; shift

  echo "case ${nn}"

  local input_file="${TEST_DIR}/parse/${nn}.vg.txt"
  local temp_tokens_file="${TEMP_DIR}/test.tokens.txt"
  local temp_vgt_file="${TEMP_DIR}/test.vgt.json"
  local exp_vgt_file="${TEST_DIR}/parse/exp_${nn}.vgt.json"

  echo "  lex" >&2
  run_exe lexer $input_file > $temp_tokens_file
  if [ $? -ne 0 ]; then
    ERRS="${ERRS},${nn}_lex"
    return
  fi

  echo "  parse" >&2
  run_exe parser $temp_tokens_file \
    > $temp_vgt_file
  if [ $? -ne 0 ]; then
    ERRS="${ERRS},${nn}_parse"
    return
  fi

  ruby ${TEST_DIR}/diff.rb json $exp_vgt_file $temp_vgt_file
  if [ $? -ne 0 ]; then
    # meld $exp_vgt_file $temp_vga_file &

    ERRS="${ERRS},parse_${nn}_diff"
    return
  fi
}

# --------------------------------

test_parse() {
  local ids="$(get_ids $MAX_ID_PARSE "$@")"

  for id in $ids; do
    test_parse_nn $(printf "%02d" $id)
  done
}

# --------------------------------

test_compile_nn() {
  local nn="$1"; shift

  echo "case ${nn}"

  local temp_tokens_file="${TEMP_DIR}/test.tokens.txt"
  local temp_vgt_file="${TEMP_DIR}/test.vgt.json"
  local temp_vga_file="${TEMP_DIR}/test.vga.txt"
  local local_errs=""
  local exp_vga_file="${TEST_DIR}/compile/exp_${nn}.vga.txt"

  echo "  lex" >&2
  run_exe lexer ${TEST_DIR}/compile/${nn}.vg.txt \
    > $temp_tokens_file
  if [ $? -ne 0 ]; then
    ERRS="${ERRS},${nn}_lex"
    local_errs="${local_errs},${nn}_lex"
    return
  fi

  echo "  parse" >&2
  run_exe parser $temp_tokens_file \
    > $temp_vgt_file
  if [ $? -ne 0 ]; then
    ERRS="${ERRS},${nn}_parse"
    local_errs="${local_errs},${nn}_parse"
    return
  fi

  echo "  codegen" >&2
  run_exe codegen $temp_vgt_file \
    > $temp_vga_file
  if [ $? -ne 0 ]; then
    ERRS="${ERRS},${nn}_cg"
    local_errs="${local_errs},${nn}_cg"
    return
  fi

  if [ "$local_errs" = "" ]; then
    ruby ${TEST_DIR}/diff.rb asm $exp_vga_file $temp_vga_file
    if [ $? -ne 0 ]; then
      # meld $exp_vga_file $temp_vga_file &

      ERRS="${ERRS},compile_${nn}_diff"
      return
    fi
  fi
}

# --------------------------------

test_compile() {
  local ids="$(get_ids $MAX_ID_STEP "$@")"

  for id in $ids; do
    test_compile_nn $(printf "%02d" $id)
  done
}

# --------------------------------

test_all() {
  echo "==== json ===="
  test_json
  if [ $? -ne 0 ]; then
    ERRS="${ERRS},${nn}_json"
    return
  fi

  echo "==== lex ===="
  test_lex
  if [ $? -ne 0 ]; then
    ERRS="${ERRS},${nn}_lex"
    return
  fi

  echo "==== parse ===="
  test_parse
  if [ $? -ne 0 ]; then
    ERRS="${ERRS},${nn}_parser"
    return
  fi

  echo "==== compile ===="
  test_compile
  if [ $? -ne 0 ]; then
    ERRS="${ERRS},${nn}_compile"
    return
  fi
}

# --------------------------------

setup
build

cmd="$1"; shift
case $cmd in
  json | j*)     #task: Run json tests
    test_json "$@"
    postproc "json"
    ;;

  lex | l*)      #task: Run lex tests
    test_lex "$@"
    postproc "lex"
    ;;

  parse | p*)    #task: Run parse tests
    test_parse "$@"
    postproc "parse"
    ;;

  compile | c*)  #task: Run compile tests
    test_compile "$@"
    postproc "compile"
    ;;

  all | a*)      #task: Run all tests
    test_all
    postproc "all"
    ;;

  run)
    # 各ステップ単独での動作確認用
    name="$1"; shift
    stdin_file="$1"; shift
    run_exe $name $stdin_file
    ;;
  *)
    echo "Tasks:"
    grep '#task: ' $0 | grep -v grep
    ;;
esac
