#!/bin/bash

set -o errexit

mkdir -p ./tmp/

file="$1"
bname=$(basename $file .vg.txt)
tokensfile=tmp/${bname}.vgtokens.txt
treefile=tmp/${bname}.vgt.json
asmfile=tmp/${bname}.vga.txt
exefile=tmp/${bname}.vge.txt

ruby vglexer.rb $file > $tokensfile
ruby vgparser.rb $tokensfile > $treefile
ruby vgcodegen.rb $treefile > $asmfile
ruby vgasm.rb $asmfile > $exefile
ruby vgvm.rb $exefile
