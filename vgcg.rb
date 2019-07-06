# coding: utf-8

# aline: assembly line

require 'json'

require './common'

$label_id = 0

def codegen_case(when_blocks)
  alines = []
  $label_id += 1
  label_id = $label_id

  when_idx = -1
  then_bodies = []

  when_blocks.each do |when_block|
    when_idx += 1
    cond, *rest = when_block
    cond_head, *cond_rest = cond
    alines << "  # 条件 #{label_id}_#{when_idx}: #{cond.inspect}"

    case cond_head
    when "eq"
      alines << "  set_reg_a #{cond_rest[0]}"
      alines << "  set_reg_b #{cond_rest[1]}"
      alines << "  compare"
      alines << "  jump_eq when_#{label_id}_#{when_idx}"

      then_alines = ["label when_#{label_id}_#{when_idx}"]
      rest.each {|stmt|
        then_alines << "  " + stmt.join(" ")
      }
      then_alines << "  jump end_case_#{label_id}"
      then_bodies << then_alines
    else
      raise not_yet_impl("cond_head", cond_head)
    end
  end

  # すべての条件が偽だった場合
  alines << "  jump end_case_#{label_id}"

  then_bodies.each {|then_alines|
    alines += then_alines
  }

  alines << "label end_case_#{label_id}"

  alines
end

def codegen_while(fn_arg_names, lvar_names, rest)
  cond_exp, body = rest
  alines = []

  $label_id += 1
  label_id = $label_id

  alines << ""

  # ループの先頭
  alines << "label while_#{label_id}"

  # 条件の評価 ... 結果が reg_a に入る
  alines += codegen_exp(lvar_names, cond_exp)
  # 比較対象の値（真）をセット
  alines << "  set_reg_b 1"
  alines << "  compare"

  # true の場合ループの本体を実行
  alines << "  jump_eq true_#{label_id}"

  # false の場合ループを抜ける
  alines << "  jump end_while_#{label_id}"

  alines << "label true_#{label_id}"
  # ループの本体
  alines += codegen_stmts(fn_arg_names, lvar_names, body)

  # ループの先頭に戻る
  alines << "  jump while_#{label_id}"

  alines << "label end_while_#{label_id}"
  alines << ""

  alines
end

def codegen_exp(lvar_names, exp)
  alines = []
  operator, *args = exp

  left =
    case args[0]
    when Integer
      args[0]
    when String
      case
      when lvar_names.include?(args[0])
        lvar_pos = lvar_names.index(args[0]) + 1
        "[bp-#{lvar_pos}]"
      else
        raise not_yet_impl("left", args[0])
      end
    else
      raise not_yet_impl("left", args[0])
    end

  right = args[1]

  case operator
  when "+"
    alines << "  set_reg_a #{left}"
    alines << "  set_reg_b #{right}"
    alines << "  add_ab"
  when "eq"
    $label_id += 1
    label_id = $label_id

    alines << "  set_reg_a #{left}"
    alines << "  set_reg_b #{right}"
    alines << "  compare"
    alines << "  jump_eq then_#{label_id}"

    # else
    alines << "  set_reg_a 0"
    alines << "  jump end_eq_#{label_id}"

    # then
    alines << "label then_#{label_id}"
    alines << "  set_reg_a 1"

    alines << "label end_eq_#{label_id}"
  else
    raise not_yet_impl("operator", operator)
  end

  alines
end

def codegen_set(fn_arg_names, lvar_names, rest)
  alines = []
  dest = rest[0]

  src_val =
    case
    when rest[1].is_a?(Integer)
      rest[1]
    when rest[1].is_a?(Array)
      exp = rest[1]
      alines += codegen_exp(lvar_names, exp)
      "reg_a"
    when fn_arg_names.include?(rest[1])
      fn_arg_pos = fn_arg_names.index(rest[1]) + 2
      "[bp+#{fn_arg_pos}]"
    when /^vram\[(.+)\]$/ =~ rest[1]
      vram_addr = $1
      alines << "  get_vram #{vram_addr} reg_a"
      "reg_a"
    else
      raise not_yet_impl("set src_val", rest)
    end

  case dest
  when /^vram\[(.+)\]$/
    vram_addr = $1
    alines << "  set_vram #{vram_addr} #{src_val}"
  else
    lvar_pos = lvar_names.index(dest) + 1
    alines << "  cp #{src_val} [bp-#{lvar_pos}]"
  end

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
      alines += codegen_set(fn_arg_names, lvar_names, stmt_rest)
    when "eq"
      alines += codegen_exp(lvar_names, stmt)
    when "return"
      val = stmt_rest[0]
      alines << "  set_reg_a #{val}"
    when "case"
      alines += codegen_case(stmt_rest)
    when "while"
      alines += codegen_while(fn_arg_names, lvar_names, stmt_rest)
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

def codegen_stmts(fn_arg_names, lvar_names, rest)
  alines = []

  rest.each do |stmt|
    stmt_head, *stmt_rest = stmt
    case stmt_head
    when "func"
      alines += codegen_func_def(stmt_rest)
    when "set"
      alines += codegen_set(fn_arg_names, lvar_names, stmt_rest)
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
  alines += codegen_stmts([], [], rest)

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
