#!/bin/bash

set -o errexit

file="$1"
bname=$(basename $file .vgt.json)
asmfile=tmp/${bname}.vga.txt
exefile=tmp/${bname}.vge.yaml

ruby vgcg.rb $file > $asmfile
ruby vgasm.rb $asmfile > $exefile
ruby vgvm.rb $exefile
