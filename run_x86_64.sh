#!/bin/bash

mkdir -p ./tmp/

file="$1"
bname=$(basename $file .vg.txt)

tokensfile=tmp/${bname}.tokens.txt
treefile=tmp/${bname}.ast.json
asmfile=tmp/${bname}.s
objfile=tmp/${bname}.o

ruby vglexer.rb $file > $tokensfile
ruby vgparser.rb $tokensfile > $treefile
ruby vgcodegen.rb $treefile > $asmfile

as -o $objfile $asmfile
gcc -o $bname $objfile

./${bname}
status=$?

echo status=${status}
