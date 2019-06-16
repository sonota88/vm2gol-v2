# coding: utf-8

# aline: assembly line

require 'json'

require './common'

def codegen_case(when_blocks)
  alines = []

  when_idx = -1
  then_bodies = []

  when_blocks.each do |when_block|
    when_idx += 1
    cond, *rest = when_block
    cond_head, *cond_rest = cond
    alines << "  # 条件 #{when_idx}: #{cond.inspect}"

    case cond_head
    when "eq"
      alines << "  set_reg_a #{cond_rest[0]}"
      alines << "  set_reg_b #{cond_rest[1]}"
      alines << "  compare"
      alines << "  jump_eq when_#{when_idx}"

      then_alines = ["label when_#{when_idx}"]
      rest.each {|stmt|
        then_alines << "  " + stmt.join(" ")
      }
      then_alines << "  jump end_case"
      then_bodies << then_alines
    else
      raise not_yet_impl("cond_head", cond_head)
    end
  end

  # すべての条件が偽だった場合
  alines << "  jump end_case"

  then_bodies.each {|then_alines|
    alines += then_alines
  }

  alines << "label end_case"

  alines
end

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
      fn_args.reverse.each {|fn_arg|
        alines << "  push #{fn_arg}"
      }
      alines << "  call #{fn_name}"
      alines << "  add_sp #{fn_args.size}"
    when "call_set"
      lvar_name, fn_temp = stmt_rest
      fn_name, *fn_args = fn_temp
      fn_args.reverse.each {|fn_arg|
        alines << "  push #{fn_arg}"
      }
      alines << "  call #{fn_name}"
      alines << "  add_sp #{fn_args.size}"

      lvar_pos = lvar_names.index(lvar_name) + 1
      alines << "  cp reg_a [bp-#{lvar_pos}]"
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
    when "return"
      val = stmt_rest[0]
      alines << "  set_reg_a #{val}"
    when "case"
      alines += codegen_case(stmt_rest)
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
