#!/bin/bash

set -o errexit

file="$1"
bname=$(basename $file .vga.txt)
exefile=tmp/${bname}.vge.yaml

ruby vgasm.rb $file > $exefile
ruby vgvm.rb $exefile
