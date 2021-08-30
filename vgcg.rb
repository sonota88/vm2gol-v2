require "json"

require_relative "./common"

$label_id = 0

def asm_prologue
  puts "  push bp"
  puts "  cp sp bp"
end

def asm_epilogue
  puts "  cp bp sp"
  puts "  pop bp"
end

def to_fn_arg_disp(fn_arg_names, fn_arg_name)
  index = fn_arg_names.index(fn_arg_name)
  index + 2
end

def to_lvar_disp(lvar_names, lvar_name)
  index = lvar_names.index(lvar_name)
  -(index + 1)
end

def _gen_expr_add
  puts "  pop reg_b"
  puts "  pop reg_a"

  puts "  add_ab"
end

def _gen_expr_mult
  puts "  pop reg_b"
  puts "  pop reg_a"

  puts "  mult_ab"
end

def _gen_expr_eq
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

def _gen_expr_neq
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

def _gen_expr_binary(fn_arg_names, lvar_names, expr)
  operator, arg_l, arg_r = expr

  gen_expr(fn_arg_names, lvar_names, arg_l)
  puts "  push reg_a"
  gen_expr(fn_arg_names, lvar_names, arg_r)
  puts "  push reg_a"

  case operator
  when "+"   then _gen_expr_add()
  when "*"   then _gen_expr_mult()
  when "=="  then _gen_expr_eq()
  when "!="  then _gen_expr_neq()
  else
    raise not_yet_impl("operator", operator)
  end
end

def gen_expr(fn_arg_names, lvar_names, expr)
  case expr
  when Integer
    puts "  cp #{expr} reg_a"
  when String
    case
    when fn_arg_names.include?(expr)
      disp = to_fn_arg_disp(fn_arg_names, expr)
      puts "  cp [bp:#{disp}] reg_a"
    when lvar_names.include?(expr)
      disp = to_lvar_disp(lvar_names, expr)
      puts "  cp [bp:#{disp}] reg_a"
    else
      raise not_yet_impl("expr", expr)
    end
  when Array
    _gen_expr_binary(fn_arg_names, lvar_names, expr)
  else
    raise not_yet_impl("expr", expr)
  end
end

def _gen_funcall(fn_arg_names, lvar_names, funcall)
  fn_name, *fn_args = funcall

  fn_args.reverse.each do |fn_arg|
    gen_expr(fn_arg_names, lvar_names, fn_arg)
    puts "  push reg_a"
  end

  gen_vm_comment("call  #{fn_name}")
  puts "  call #{fn_name}"
  puts "  add_sp #{fn_args.size}"
end

def gen_call(fn_arg_names, lvar_names, stmt)
  _, *funcall = stmt
  _gen_funcall(fn_arg_names, lvar_names, funcall)
end

def gen_call_set(fn_arg_names, lvar_names, stmt)
  _, lvar_name, funcall = stmt

  _gen_funcall(fn_arg_names, lvar_names, funcall)

  disp = to_lvar_disp(lvar_names, lvar_name)
  puts "  cp reg_a [bp:#{disp}]"
end

def _gen_set(fn_arg_names, lvar_names, dest, expr)
  gen_expr(fn_arg_names, lvar_names, expr)
  src_val = "reg_a"

  case
  when lvar_names.include?(dest)
    disp = to_lvar_disp(lvar_names, dest)
    puts "  cp #{src_val} [bp:#{disp}]"
  else
    raise not_yet_impl("dest", dest)
  end
end

def gen_set(fn_arg_names, lvar_names, stmt)
  _, dest, expr = stmt
  _gen_set(fn_arg_names, lvar_names, dest, expr)
end

def gen_return(lvar_names, stmt)
  _, retval = stmt
  gen_expr([], lvar_names, retval);
end

def gen_while(fn_arg_names, lvar_names, stmt)
  _, cond_expr, body = stmt

  $label_id += 1
  label_id = $label_id

  label_begin = "while_#{label_id}"
  label_end = "end_while_#{label_id}"
  label_true = "true_#{label_id}"

  puts ""

  # ループの先頭
  puts "label #{label_begin}"

  # 条件の評価 ... 結果が reg_a に入る
  gen_expr(fn_arg_names, lvar_names, cond_expr)
  # 比較対象の値をセット
  puts "  cp 0 reg_b"
  puts "  compare"

  # false の場合ループを抜ける
  puts "  jump_eq #{label_end}"

  # ループの本体
  gen_stmts(fn_arg_names, lvar_names, body)

  # ループの先頭に戻る
  puts "  jump #{label_begin}"

  puts "label #{label_end}"
  puts ""
end

def gen_case(fn_arg_names, lvar_names, stmt)
  _, *when_clauses = stmt

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
    gen_expr(fn_arg_names, lvar_names, cond)
    puts "  # <<-- expr"

    # 式の結果と比較するための値を reg_b に入れる
    puts "  cp 0 reg_b"

    puts "  compare"
    puts "  jump_eq #{label_end_when_head}_#{when_idx}" # 偽の場合

    gen_stmts(fn_arg_names, lvar_names, rest)

    puts "  jump #{label_end}"

    # 偽の場合ここにジャンプ
    puts "label #{label_end_when_head}_#{when_idx}"
  end

  puts "label #{label_end}"
  puts "  # <<-- case_#{label_id}"
  puts ""
end

def gen_vm_comment(comment)
  puts "  _cmt " + comment.gsub(" ", "~")
end

def gen_debug
  puts "  _debug"
end

def gen_stmt(fn_arg_names, lvar_names, stmt)
  case stmt[0]
  when "call"
    gen_call(fn_arg_names, lvar_names, stmt)
  when "call_set"
    gen_call_set(fn_arg_names, lvar_names, stmt)
  when "set"
    gen_set(fn_arg_names, lvar_names, stmt)
  when "return"
    gen_return(lvar_names, stmt)
  when "case"
    gen_case(fn_arg_names, lvar_names, stmt)
  when "while"
    gen_while(fn_arg_names, lvar_names, stmt)
  when "_cmt"
    gen_vm_comment(stmt[1])
  when "_debug"
    gen_debug()
  else
    raise not_yet_impl("stmt", stmt)
  end
end

def gen_stmts(fn_arg_names, lvar_names, stmts)
  stmts.each do |stmt|
    gen_stmt(fn_arg_names, lvar_names, stmt)
  end
end

def gen_var(fn_arg_names, lvar_names, stmt)
  puts "  sub_sp 1"

  if stmt.size == 3
    _, dest, expr = stmt
    _gen_set(fn_arg_names, lvar_names, dest, expr)
  end
end

def gen_func_def(func_def)
  _, fn_name, fn_arg_names, body = func_def

  puts ""
  puts "label #{fn_name}"
  asm_prologue()

  puts ""
  puts "  # 関数の処理本体"

  lvar_names = []

  body.each do |stmt|
    if stmt[0] == "var"
      lvar_names << stmt[1]
      gen_var(fn_arg_names, lvar_names, stmt)
    else
      gen_stmt(fn_arg_names, lvar_names, stmt)
    end
  end

  puts ""
  asm_epilogue()
  puts "  ret"
end

def gen_top_stmts(tree)
  _, *top_stmts = tree

  top_stmts.each do |top_stmt|
    case top_stmt[0]
    when "func"
      gen_func_def(top_stmt)
    else
      raise not_yet_impl("top_stmt", top_stmt)
    end
  end
end

def gen_builtin_set_vram
  puts ""
  puts "label set_vram"
  asm_prologue()
  puts "  set_vram [bp:2] [bp:3]" # vram_addr value
  asm_epilogue()
  puts "  ret"
end

def gen_builtin_get_vram
  puts ""
  puts "label get_vram"
  asm_prologue()
  puts "  get_vram [bp:2] reg_a" # vram_addr dest
  asm_epilogue()
  puts "  ret"
end

def codegen(tree)
  puts "  call main"
  puts "  exit"

  gen_top_stmts(tree)

  gen_builtin_set_vram()
  gen_builtin_get_vram()
end

# vgtコード読み込み
src = File.read(ARGV[0])

# 構文木に変換
tree = JSON.parse(src)

# コード生成（アセンブリコードに変換）
codegen(tree)
