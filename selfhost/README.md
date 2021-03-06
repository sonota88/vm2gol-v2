2021-03-06 別リポジトリに移動しました。
今後の開発はこちらで進めます。  

https://github.com/sonota88/pric

----

第1世代: Ruby版 v3 コンパイラ

```sh
# テスト
rake test_v3
```

```sh
# コンパイル
../pricc ../examples/fibonacci.pric > fibonacci.exe.txt

# 実行ファイルを VM で実行
../pricvm fibonacci.exe.txt

# コンパイル＋実行
../pricrun ../examples/fibonacci.pric
```

第2世代: Pric版 v3 コンパイラ

```sh
# テスト
./test.sh all
```

```sh
mkdir -p exe

# 第2世代コンパイラでライフゲームをコンパイル
./pricc ../examples/gol.pric > exe/gol.exe.txt

# VM で実行
VERBOSE=1 SKIP=100 ../pricvm exe/gol.exe.txt

# コンパイル＋実行
VERBOSE=1 SKIP=100 ./pricrun ../examples/gol.pric
```

```sh
# (1) 第1世代コンパイラで第2世代コンパイラをコンパイル
# (2) (1) で生成された実行ファイル（第2世代コンパイラ）で第2世代コンパイラ自身をコンパイル

# 上記 (1), (2) の出力（実行ファイル）が一致することを確認:
./test_selfhost.sh
# （作者の環境だと 15分程度）
```
