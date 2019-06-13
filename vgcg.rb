# coding: utf-8

# aline: assembly line

require 'json'

require './common'

def codegen_func_def(rest)
  alines = []

  fn_name = rest[0]
  fn_arg_names = rest[1]
  body = rest[2]

  alines << ""
  alines << "label #{fn_name}"
  alines << "  push bp"
  alines << "  cp sp bp"

  alines << ""
  alines << "  # 関数の処理本体"

  lvar_names = []

  body.each {|stmt|
    stmt_head, *stmt_rest = stmt
    case stmt_head
    when "call"
      fn_name, *fn_args = stmt_rest
      alines << "  push #{fn_args[0]}"
      alines << "  call #{fn_name}"
      alines << "  add_sp #{fn_args.size}"
    when "var"
      lvar_names << stmt_rest[0]
      alines << "  sub_sp 1"
    when "set"
      lvar_name = stmt_rest[0]

      val =
        case
        when stmt_rest[1].is_a?(Integer)
          stmt_rest[1]
        when fn_arg_names.include?(stmt_rest[1])
          fn_arg_pos = fn_arg_names.index(stmt_rest[1]) + 2
          "[bp+#{fn_arg_pos}]"
        else
          raise not_yet_impl("set val", stmt_rest)
        end

      lvar_pos = lvar_names.index(lvar_name) + 1
      alines << "  cp #{val} [bp-#{lvar_pos}]"
    else
      raise not_yet_impl("stmt_head", stmt_head)
    end
  }

  alines << ""
  alines << "  cp bp sp"
  alines << "  pop bp"
  alines << "  ret"

  alines
end

def codegen_stmts(rest)
  alines = []

  rest.each do |stmt|
    stmt_head, *stmt_rest = stmt
    case stmt_head
    when "func"
      alines += codegen_func_def(stmt_rest)
    else
      raise not_yet_impl("stmt_head", stmt_head)
    end
  end

  alines
end

def codegen(tree)
  alines = []

  alines << "  call main"
  alines << "  exit"

  head, *rest = tree
  # assert head == "stmts"
  alines += codegen_stmts(rest)

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
