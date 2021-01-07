#!/bin/bash

set -o errexit

mkdir -p ./tmp/

file="$1"
bname=$(basename $file .vg.txt)
treefile=tmp/${bname}.vgt.json
asmfile=tmp/${bname}.vga.txt
exefile=tmp/${bname}.vge.txt

ruby vgparser.rb $file > $treefile
ruby vgcg.rb $treefile > $asmfile
ruby vgasm.rb $asmfile > $exefile
ruby vgvm.rb $exefile
