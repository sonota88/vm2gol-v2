```sh
# v2 コンパイラ（Pric版）のテストを実行
./test.sh all

# v3 コンパイラ（Ruby版）を使ってコンパイル
../pricc example.pric > example.exe.txt

# 実行ファイルを VM で実行
../pricvm example.exe.txt

# コンパイル＋実行
../pricrun example.pric
```
