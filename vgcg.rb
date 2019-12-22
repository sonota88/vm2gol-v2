# coding: utf-8

# aline: assembly line

require 'json'

require './common'

$label_id = 0

def to_fn_arg_addr(fn_arg_names, fn_arg_name)
  index = fn_arg_names.index(fn_arg_name)
  "[bp+#{index + 2}]"
end

def to_lvar_addr(lvar_names, lvar_name)
  index = lvar_names.index(lvar_name)
  "[bp-#{index + 1}]"
end

def codegen_case(fn_arg_names, lvar_names, when_blocks)
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
      # 式の結果が reg_a に入る
      alines += codegen_exp(fn_arg_names, lvar_names, cond)

      # 式の結果と比較するための値を reg_b に入れる
      alines << "  set_reg_b 1"

      alines << "  compare"
      alines << "  jump_eq when_#{label_id}_#{when_idx}"

      then_alines = ["label when_#{label_id}_#{when_idx}"]
      then_alines += codegen_stmts(fn_arg_names, lvar_names, rest)
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
  alines += codegen_exp(fn_arg_names, lvar_names, cond_exp)
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

def codegen_exp_term(fn_arg_names, lvar_names, exp)
  alines = []

  val_to_push =
    case exp
    when Integer
      exp
    when String
      case
      when lvar_names.include?(exp)
        to_lvar_addr(lvar_names, exp)
      when fn_arg_names.include?(exp)
        to_fn_arg_addr(fn_arg_names, exp)
      else
        raise not_yet_impl("exp", exp)
      end
    when Array
      alines += codegen_exp(fn_arg_names, lvar_names, exp)
      "reg_a"
    else
      raise not_yet_impl("exp", exp)
    end

  alines << "  push #{val_to_push}"

  alines
end

def codegen_exp(fn_arg_names, lvar_names, exp)
  alines = []
  operator, *args = exp

  alines += codegen_exp_term(fn_arg_names, lvar_names, args[0])
  alines += codegen_exp_term(fn_arg_names, lvar_names, args[1])

  case operator
  when "+"
    alines << "  pop reg_b"
    alines << "  pop reg_a"

    alines << "  add_ab"
  when "*"
    alines << "  pop reg_b"
    alines << "  pop reg_a"

    alines << "  mult_ab"
  when "eq"
    $label_id += 1
    label_id = $label_id

    alines << "  pop reg_b"
    alines << "  pop reg_a"

    alines << "  compare"
    alines << "  jump_eq then_#{label_id}"

    # else
    alines << "  set_reg_a 0"
    alines << "  jump end_eq_#{label_id}"

    # then
    alines << "label then_#{label_id}"
    alines << "  set_reg_a 1"

    alines << "label end_eq_#{label_id}"
  when "neq"
    $label_id += 1
    label_id = $label_id

    alines << "  pop reg_b"
    alines << "  pop reg_a"

    alines << "  compare"
    alines << "  jump_eq then_#{label_id}"

    # else
    alines << "  set_reg_a 1"
    alines << "  jump end_neq_#{label_id}"

    # then
    alines << "label then_#{label_id}"
    alines << "  set_reg_a 0"

    alines << "label end_neq_#{label_id}"
  else
    raise not_yet_impl("operator", operator)
  end

  alines
end

def codegen_call(fn_arg_names, lvar_names, stmt_rest)
  alines = []

  fn_name, *fn_args = stmt_rest
  fn_args.reverse.each {|fn_arg|
    case fn_arg
    when Integer
      alines << "  push #{fn_arg}"
    when String
      case
      when fn_arg_names.include?(fn_arg)
        fn_arg_addr = to_fn_arg_addr(fn_arg_names, fn_arg)
        alines << "  push #{fn_arg_addr}"
      when lvar_names.include?(fn_arg)
        lvar_addr = to_lvar_addr(lvar_names, fn_arg)
        alines << "  push #{lvar_addr}"
      else
        raise not_yet_impl(fn_arg)
      end
    else
      raise not_yet_impl(fn_arg)
    end
  }
  alines += codegen_comment("call  #{fn_name}")
  alines << "  call #{fn_name}"
  alines << "  add_sp #{fn_args.size}"

  alines
end

def codegen_call_set(fn_arg_names, lvar_names, stmt_rest)
  alines = []

  lvar_name, fn_temp = stmt_rest

  alines += codegen_call(fn_arg_names, lvar_names, fn_temp)

  lvar_addr = to_lvar_addr(lvar_names, lvar_name)
  alines << "  cp reg_a #{lvar_addr}"

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
      alines += codegen_exp(fn_arg_names, lvar_names, exp)
      "reg_a"
    when fn_arg_names.include?(rest[1])
      to_fn_arg_addr(fn_arg_names, rest[1])
    when lvar_names.include?(rest[1])
      to_lvar_addr(lvar_names, rest[1])
    when /^vram\[(\d+)\]$/ =~ rest[1]
      vram_addr = $1
      alines << "  get_vram #{vram_addr} reg_a"
      "reg_a"
    when /^vram\[([a-z_][a-z0-9_]*)\]$/ =~ rest[1]
      var_name = $1
      case
      when lvar_names.include?(var_name)
        lvar_addr = to_lvar_addr(lvar_names, var_name)
        alines << "  get_vram #{ lvar_addr } reg_a"
      else
        raise not_yet_impl("rest", rest)
      end
      "reg_a"
    else
      raise not_yet_impl("set src_val", rest)
    end

  case dest
  when /^vram\[(.+)\]$/
    vram_addr = $1
    case
    when /^\d+$/ =~ vram_addr
      alines << "  set_vram #{vram_addr} #{src_val}"
    when lvar_names.include?(vram_addr)
      lvar_addr = to_lvar_addr(lvar_names, vram_addr)
      alines << "  set_vram #{lvar_addr} #{src_val}"
    else
      raise not_yet_impl("vram_addr", vram_addr)
    end
  else
    lvar_addr = to_lvar_addr(lvar_names, dest)
    alines << "  cp #{src_val} #{lvar_addr}"
  end

  alines
end

def codegen_return(lvar_names, stmt_rest)
  alines = []

  retval = stmt_rest[0]

  case retval
  when Integer
    alines << "  set_reg_a #{retval}"
  when String
    case
    when /^vram\[([a-z0-9_]+)\]$/ =~ retval
      var_name = $1
      case
      when lvar_names.include?(var_name)
        lvar_addr = to_lvar_addr(lvar_names, var_name)
        alines << "  get_vram #{lvar_addr} reg_a"
      else
        raise not_yet_impl("retval", retval)
      end
    when lvar_names.include?(retval)
      lvar_addr = to_lvar_addr(lvar_names, retval)
      alines << "  cp #{lvar_addr} reg_a"
    else
      raise not_yet_impl("retval", retval)
    end
  else
    raise not_yet_impl("retval", retval)
  end

  alines
end

def codegen_comment(comment)
  [
    "  _cmt " + comment.gsub(" ", "~")
  ]
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
      alines += codegen_call(fn_arg_names, lvar_names, stmt_rest)
    when "call_set"
      alines += codegen_call_set(fn_arg_names, lvar_names, stmt_rest)
    when "var"
      lvar_names << stmt_rest[0]
      alines << "  sub_sp 1"
      if stmt_rest.size == 2
        alines += codegen_set(fn_arg_names, lvar_names, stmt_rest)
      end
    when "set"
      alines += codegen_set(fn_arg_names, lvar_names, stmt_rest)
    when "eq"
      alines += codegen_exp(fn_arg_names, lvar_names, stmt)
    when "return"
      alines += codegen_return(lvar_names, stmt_rest)
    when "case"
      alines += codegen_case(fn_arg_names, lvar_names, stmt_rest)
    when "while"
      alines += codegen_while(fn_arg_names, lvar_names, stmt_rest)
    when "_cmt"
      alines += codegen_comment(stmt_rest[0])
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
    when "call"
      alines += codegen_call(fn_arg_names, lvar_names, stmt_rest)
    when "call_set"
      alines += codegen_call_set(fn_arg_names, lvar_names, stmt_rest)
    when "set"
      alines += codegen_set(fn_arg_names, lvar_names, stmt_rest)
    when "case"
      alines += codegen_case(fn_arg_names, lvar_names, stmt_rest)
    when "while"
      alines += codegen_while(fn_arg_names, lvar_names, stmt_rest)
    when "_cmt"
      alines += codegen_comment(stmt_rest[0])
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
