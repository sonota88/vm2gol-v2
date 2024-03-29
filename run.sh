#!/bin/bash

set -o errexit

mkdir -p ./tmp/

file="$1"
bname=$(basename $file .vg.txt)
tokensfile=tmp/${bname}.vgtokens.txt
treefile=tmp/${bname}.vgt.json
asmfile=tmp/${bname}.vga.txt
exefile=tmp/${bname}.vge.txt

ruby mrcl_lexer.rb $file > $tokensfile
ruby mrcl_parser.rb $tokensfile > $treefile
ruby mrcl_codegen.rb $treefile > $asmfile
ruby mrcl_asm.rb $asmfile > $exefile
ruby mrcl_vm.rb $exefile
