# coding: utf-8

# aline: assembly line

require 'json'

def codegen(tree)
  alines = []

  fn_name = tree[1]
  body = tree[3]

  alines << "  call main"
  alines << "  exit"

  alines << ""
  alines << "label #{fn_name}"
  alines << "  push bp"
  alines << "  cp sp bp"

  alines << ""
  alines << "  # 関数の処理本体"
  body.each {|stmt|
    alines << "  # TODO"
  }

  alines << ""
  alines << "  cp bp sp"
  alines << "  pop bp"
  alines << "  ret"

  alines
end

# vgtコード読み込み
src = File.read(ARGV[0])

# 構文木に変換
tree = JSON.parse(src)

# コード生成（アセンブリコードに変換）
alines = codegen(tree)

# アセンブリコードを出力
alines.each {|aline|
  puts aline
}
