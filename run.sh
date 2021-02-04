#!/bin/bash

set -o errexit
set -o nounset

print_this_dir() {
  (
    cd "$(dirname $0)"
    pwd
  )
}

__DIR__="$(print_this_dir)"
TEMP_DIR=${__DIR__}/tmp/

mkdir -p $TEMP_DIR

file="$1"
# bname=$(basename $file .vg.txt)
bname=run

src_temp=tmp/${bname}.pric.rb

ruby ${__DIR__}/preproc.rb $file > $src_temp

tokensfile=${TEMP_DIR}/${bname}.vgtokens.txt
treefile=${TEMP_DIR}/${bname}.vgt.json
asmfile=${TEMP_DIR}/${bname}.vga.txt
exefile=${TEMP_DIR}/${bname}.vge.txt

ruby vglexer.rb $src_temp > $tokensfile
ruby vgparser.rb $tokensfile > $treefile
ruby vgcg.rb $treefile > $asmfile
ruby vgasm.rb $asmfile > $exefile
ruby vgvm.rb $exefile
