# coding: utf-8

require "json"

require_relative "./common"

$label_id = 0

def to_fn_arg_addr(fn_arg_names, fn_arg_name)
  index = fn_arg_names.index(fn_arg_name)
  "[bp:#{index + 2}]"
end

def to_lvar_addr(lvar_names, lvar_name)
  index = lvar_names.index(lvar_name)
  "[bp:-#{index + 1}]"
end

def codegen_var(fn_arg_names, lvar_names, stmt_rest)
  puts "  sub_sp 1"

  if stmt_rest.size == 2
    codegen_set(fn_arg_names, lvar_names, stmt_rest)
  end
end

def codegen_case(fn_arg_names, lvar_names, when_clauses)
  $label_id += 1
  label_id = $label_id

  when_idx = -1

  label_end = "end_case_#{label_id}"
  label_when_head = "when_#{label_id}"
  label_end_when_head = "end_when_#{label_id}"

  puts ""
  puts "  # -->> case_#{label_id}"

  when_clauses.each do |when_clause|
    when_idx += 1
    cond, *rest = when_clause

    puts "  # when_#{label_id}_#{when_idx}: #{cond.inspect}"

    # 式の結果が reg_a に入る
    puts "  # -->> expr"
    codegen_expr(fn_arg_names, lvar_names, cond)
    puts "  # <<-- expr"

    # 式の結果と比較するための値を reg_b に入れる
    puts "  cp 1 reg_b"

    puts "  compare"
    puts "  jump_eq #{label_when_head}_#{when_idx}"  # 真の場合
    puts "  jump #{label_end_when_head}_#{when_idx}" # 偽の場合

    # 真の場合ここにジャンプ
    puts "label #{label_when_head}_#{when_idx}"

    codegen_stmts(fn_arg_names, lvar_names, rest)

    puts "  jump #{label_end}"

    # 偽の場合ここにジャンプ
    puts "label #{label_end_when_head}_#{when_idx}"
  end

  puts "label #{label_end}"
  puts "  # <<-- case_#{label_id}"
  puts ""
end

def codegen_while(fn_arg_names, lvar_names, rest)
  cond_expr, body = rest

  $label_id += 1
  label_id = $label_id

  label_begin = "while_#{label_id}"
  label_end = "end_while_#{label_id}"
  label_true = "true_#{label_id}"

  puts ""

  # ループの先頭
  puts "label #{label_begin}"

  # 条件の評価 ... 結果が reg_a に入る
  codegen_expr(fn_arg_names, lvar_names, cond_expr)
  # 比較対象の値（真）をセット
  puts "  cp 1 reg_b"
  puts "  compare"

  # true の場合ループの本体を実行
  puts "  jump_eq #{label_true}"

  # false の場合ループを抜ける
  puts "  jump #{label_end}"

  puts "label #{label_true}"
  # ループの本体
  codegen_stmts(fn_arg_names, lvar_names, body)

  # ループの先頭に戻る
  puts "  jump #{label_begin}"

  puts "label #{label_end}"
  puts ""
end

def _codegen_expr_add
  puts "  pop reg_b"
  puts "  pop reg_a"

  puts "  add_ab"
end

def _codegen_expr_mult
  puts "  pop reg_b"
  puts "  pop reg_a"

  puts "  mult_ab"
end

def _codegen_expr_eq
  $label_id += 1
  label_id = $label_id

  label_end = "end_eq_#{label_id}"
  label_then = "then_#{label_id}"

  puts "  pop reg_b"
  puts "  pop reg_a"

  puts "  compare"
  puts "  jump_eq #{label_then}"

  # else
  puts "  cp 0 reg_a"
  puts "  jump #{label_end}"

  # then
  puts "label #{label_then}"
  puts "  cp 1 reg_a"

  puts "label #{label_end}"
end

def _codegen_expr_neq
  $label_id += 1
  label_id = $label_id

  label_end = "end_neq_#{label_id}"
  label_then = "then_#{label_id}"

  puts "  pop reg_b"
  puts "  pop reg_a"

  puts "  compare"
  puts "  jump_eq #{label_then}"

  # else
  puts "  cp 1 reg_a"
  puts "  jump #{label_end}"

  # then
  puts "label #{label_then}"
  puts "  cp 0 reg_a"

  puts "label #{label_end}"
end

def _codegen_expr_binary(fn_arg_names, lvar_names, expr)
  operator, arg_l, arg_r = expr

  codegen_expr(fn_arg_names, lvar_names, arg_l)
  puts "  push reg_a"
  codegen_expr(fn_arg_names, lvar_names, arg_r)
  puts "  push reg_a"

  case operator
  when "+"   then _codegen_expr_add()
  when "*"   then _codegen_expr_mult()
  when "eq"  then _codegen_expr_eq()
  when "neq" then _codegen_expr_neq()
  else
    raise not_yet_impl("operator", operator)
  end
end

def codegen_expr(fn_arg_names, lvar_names, expr)
  case expr
  when Integer
    puts "  cp #{expr} reg_a"
  when String
    case
    when fn_arg_names.include?(expr)
      cp_src = to_fn_arg_addr(fn_arg_names, expr)
      puts "  cp #{cp_src} reg_a"
    when lvar_names.include?(expr)
      cp_src = to_lvar_addr(lvar_names, expr)
      puts "  cp #{cp_src} reg_a"
    else
      raise not_yet_impl("expr", expr)
    end
  when Array
    _codegen_expr_binary(fn_arg_names, lvar_names, expr)
  else
    raise not_yet_impl("expr", expr)
  end
end

def codegen_call(fn_arg_names, lvar_names, stmt_rest)
  fn_name, *fn_args = stmt_rest

  fn_args.reverse.each do |fn_arg|
    codegen_expr(fn_arg_names, lvar_names, fn_arg)
    puts "  push reg_a"
  end

  codegen_vm_comment("call  #{fn_name}")
  puts "  call #{fn_name}"
  puts "  add_sp #{fn_args.size}"
end

def codegen_call_set(fn_arg_names, lvar_names, stmt_rest)
  lvar_name, funcall = stmt_rest

  codegen_call(fn_arg_names, lvar_names, funcall)

  lvar_addr = to_lvar_addr(lvar_names, lvar_name)
  puts "  cp reg_a #{lvar_addr}"
end

def codegen_set(fn_arg_names, lvar_names, rest)
  dest = rest[0]
  expr = rest[1]

  codegen_expr(fn_arg_names, lvar_names, expr)
  src_val = "reg_a"

  case
  when lvar_names.include?(dest)
    lvar_addr = to_lvar_addr(lvar_names, dest)
    puts "  cp #{src_val} #{lvar_addr}"
  else
    raise not_yet_impl("dest", dest)
  end
end

def codegen_return(lvar_names, stmt_rest)
  retval = stmt_rest[0]
  codegen_expr([], lvar_names, retval);
end

def codegen_vm_comment(comment)
  puts "  _cmt " + comment.gsub(" ", "~")
end

def codegen_stmt(fn_arg_names, lvar_names, stmt)
  stmt_head, *stmt_rest = stmt

  case stmt_head
  when "call"
    codegen_call(fn_arg_names, lvar_names, stmt_rest)
  when "call_set"
    codegen_call_set(fn_arg_names, lvar_names, stmt_rest)
  when "set"
    codegen_set(fn_arg_names, lvar_names, stmt_rest)
  when "return"
    codegen_return(lvar_names, stmt_rest)
  when "case"
    codegen_case(fn_arg_names, lvar_names, stmt_rest)
  when "while"
    codegen_while(fn_arg_names, lvar_names, stmt_rest)
  when "_cmt"
    codegen_vm_comment(stmt_rest[0])
  else
    raise not_yet_impl("stmt_head", stmt_head)
  end
end

def codegen_stmts(fn_arg_names, lvar_names, stmts)
  stmts.each do |stmt|
    codegen_stmt(fn_arg_names, lvar_names, stmt)
  end
end

def codegen_func_def(rest)
  fn_name = rest[0]
  fn_arg_names = rest[1]
  body = rest[2]

  puts ""
  puts "label #{fn_name}"
  puts "  push bp"
  puts "  cp sp bp"

  puts ""
  puts "  # 関数の処理本体"

  lvar_names = []

  body.each do |stmt|
    if stmt[0] == "var"
      _, *stmt_rest = stmt
      lvar_names << stmt_rest[0]
      codegen_var(fn_arg_names, lvar_names, stmt_rest)
    else
      codegen_stmt(fn_arg_names, lvar_names, stmt)
    end
  end

  puts ""
  puts "  cp bp sp"
  puts "  pop bp"
  puts "  ret"
end

def codegen_top_stmts(rest)
  rest.each do |stmt|
    stmt_head, *stmt_rest = stmt
    case stmt_head
    when "func"
      codegen_func_def(stmt_rest)
    when "_cmt"
      codegen_vm_comment(stmt_rest[0])
    else
      raise not_yet_impl("stmt_head", stmt_head)
    end
  end
end

def codegen_builtin_set_vram
  puts ""
  puts "label set_vram"
  puts "  push bp"
  puts "  cp sp bp"

  puts "  set_vram [bp:2] [bp:3]" # vram_addr value

  puts "  cp bp sp"
  puts "  pop bp"
  puts "  ret"
end

def codegen_builtin_get_vram
  puts ""
  puts "label get_vram"
  puts "  push bp"
  puts "  cp sp bp"

  puts "  get_vram [bp:2] reg_a" # vram_addr dest

  puts "  cp bp sp"
  puts "  pop bp"
  puts "  ret"
end

def codegen(tree)
  puts "  call main"
  puts "  exit"

  head, *rest = tree
  # assert head == "top_stmts"
  codegen_top_stmts(rest)

  codegen_builtin_set_vram()
  codegen_builtin_get_vram()
end

# vgtコード読み込み
src = File.read(ARGV[0])

# 構文木に変換
tree = JSON.parse(src)

# コード生成（アセンブリコードに変換）
codegen(tree)
