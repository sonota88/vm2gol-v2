#!/bin/bash

set -o errexit

mkdir -p ./tmp/

file="$1"
# bname=$(basename $file .vg.txt)
bname=run

src_temp=tmp/${bname}.pric.rb

ruby preproc.rb $file > $src_temp

tokensfile=tmp/${bname}.vgtokens.txt
treefile=tmp/${bname}.vgt.json
asmfile=tmp/${bname}.vga.txt
exefile=tmp/${bname}.vge.txt

ruby vglexer.rb $src_temp > $tokensfile
ruby vgparser.rb $tokensfile > $treefile
ruby vgcg.rb $treefile > $asmfile
ruby vgasm.rb $asmfile > $exefile
ruby vgvm.rb $exefile
