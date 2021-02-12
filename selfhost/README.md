第1世代: Ruby版 v3 コンパイラ

```sh
# テスト
rake test_v3
```

```sh
# コンパイル
../pricc ../example.pric > example.exe.txt

# 実行ファイルを VM で実行
../pricvm example.exe.txt

# コンパイル＋実行
../pricrun ../example.pric
```

第2世代: Pric版 v2 コンパイラ

```sh
# テスト
./test.sh all
```

```sh
mkdir -p exe

# 第2世代コンパイラでライフゲームをコンパイル
./pricc examples/gol.pric > exe/gol.exe.txt

# VM で実行
VERBOSE=1 SKIP=100 ../pricvm exe/gol.exe.txt

# コンパイル＋実行
VERBOSE=1 SKIP=100 ./pricrun examples/gol.pric
```
