# coding: utf-8

require "json"

require_relative "./common"

$label_id = 0

def to_fn_arg_addr(fn_arg_names, fn_arg_name)
  index = fn_arg_names.index(fn_arg_name)
  "[bp+#{index + 2}]"
end

def to_lvar_addr(lvar_names, lvar_name)
  index = lvar_names.index(lvar_name)
  "[bp-#{index + 1}]"
end

def codegen_var(fn_arg_names, lvar_names, stmt_rest)
  puts "  sub_sp 1"

  if stmt_rest.size == 2
    codegen_set(fn_arg_names, lvar_names, stmt_rest)
  end
end

def codegen_case(fn_arg_names, lvar_names, when_blocks)
  $label_id += 1
  label_id = $label_id

  when_idx = -1

  label_end = "end_case_#{label_id}"
  label_when_head = "when_#{label_id}"
  label_end_when_head = "end_when_#{label_id}"

  puts ""
  puts "  # -->> case_#{label_id}"

  when_blocks.each do |when_block|
    when_idx += 1
    cond, *rest = when_block
    cond_head, *cond_rest = cond

    puts "  # when_#{label_id}_#{when_idx}: #{cond.inspect}"

    case cond_head
    when "eq"
      # 式の結果が reg_a に入る
      puts "  # -->> expr"
      _codegen_expr_binary(fn_arg_names, lvar_names, cond)
      puts "  # <<-- expr"

      # 式の結果と比較するための値を reg_b に入れる
      puts "  set_reg_b 1"

      puts "  compare"
      puts "  jump_eq #{label_when_head}_#{when_idx}"  # 真の場合
      puts "  jump #{label_end_when_head}_#{when_idx}" # 偽の場合

      # 真の場合ここにジャンプ
      puts "label #{label_when_head}_#{when_idx}"

      codegen_stmts(fn_arg_names, lvar_names, rest)

      puts "  jump #{label_end}"

      # 偽の場合ここにジャンプ
      puts "label #{label_end_when_head}_#{when_idx}"

    else
      raise not_yet_impl("cond_head", cond_head)
    end
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
  _codegen_expr_binary(fn_arg_names, lvar_names, cond_expr)
  # 比較対象の値（真）をセット
  puts "  set_reg_b 1"
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
  puts "  set_reg_a 0"
  puts "  jump #{label_end}"

  # then
  puts "label #{label_then}"
  puts "  set_reg_a 1"

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
  puts "  set_reg_a 1"
  puts "  jump #{label_end}"

  # then
  puts "label #{label_then}"
  puts "  set_reg_a 0"

  puts "label #{label_end}"
end

def _codegen_expr_binary(fn_arg_names, lvar_names, expr)
  operator, *args = expr

  arg_l = args[0]
  arg_r = args[1]

  codegen_expr(fn_arg_names, lvar_names, arg_l)
  puts "  push reg_a"
  codegen_expr(fn_arg_names, lvar_names, arg_r)
  puts "  push reg_a"

  case operator
  when "+"
    _codegen_expr_add()
  when "*"
    _codegen_expr_mult()
  when "eq"
    _codegen_expr_eq()
  when "neq"
    _codegen_expr_neq()
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

def _codegen_call_push_fn_arg(fn_arg_names, lvar_names, fn_arg)
  push_arg =
    case fn_arg
    when Integer
      fn_arg
    when String
      case
      when fn_arg_names.include?(fn_arg)
        to_fn_arg_addr(fn_arg_names, fn_arg)
      when lvar_names.include?(fn_arg)
        to_lvar_addr(lvar_names, fn_arg)
      else
        raise not_yet_impl(fn_arg)
      end
    else
      raise not_yet_impl(fn_arg)
    end

  puts "  push #{push_arg}"
end

def codegen_call(fn_arg_names, lvar_names, stmt_rest)
  fn_name, *fn_args = stmt_rest

  fn_args.reverse.each do |fn_arg|
    _codegen_call_push_fn_arg(
      fn_arg_names, lvar_names, fn_arg
    )
  end

  codegen_vm_comment("call  #{fn_name}")
  puts "  call #{fn_name}"
  puts "  add_sp #{fn_args.size}"
end

def codegen_call_set(fn_arg_names, lvar_names, stmt_rest)
  lvar_name, fn_temp = stmt_rest
  fn_name, *fn_args = fn_temp

  fn_args.reverse.each do |fn_arg|
    _codegen_call_push_fn_arg(
      fn_arg_names, lvar_names, fn_arg
    )
  end

  codegen_vm_comment("call_set  #{fn_name}")
  puts "  call #{fn_name}"
  puts "  add_sp #{fn_args.size}"

  lvar_addr = to_lvar_addr(lvar_names, lvar_name)
  puts "  cp reg_a #{lvar_addr}"
end

def _match_vram_addr(str)
  md = /^vram\[(\d+)\]$/.match(str)
  return nil if md.nil?

  md[1]
end

def _match_vram_ref(str)
  md = /^vram\[([a-z_][a-z0-9_]*)\]$/.match(str)
  return nil if md.nil?

  md[1]
end

def codegen_set(fn_arg_names, lvar_names, rest)
  dest = rest[0]
  expr = rest[1]

  src_val =
    case expr
    when Integer
      expr
    when Array
      _codegen_expr_binary(fn_arg_names, lvar_names, expr)
      "reg_a"
    when String
      case
      when fn_arg_names.include?(expr)
        to_fn_arg_addr(fn_arg_names, expr)
      when lvar_names.include?(expr)
        to_lvar_addr(lvar_names, expr)
      when _match_vram_addr(expr)
        vram_addr = _match_vram_addr(expr)
        puts "  get_vram #{vram_addr} reg_a"
        "reg_a"
      when _match_vram_ref(expr)
        var_name = _match_vram_ref(expr)
        case
        when lvar_names.include?(var_name)
          lvar_addr = to_lvar_addr(lvar_names, var_name)
          puts "  get_vram #{ lvar_addr } reg_a"
        else
          raise not_yet_impl("rest", rest)
        end
        "reg_a"
      else
        raise not_yet_impl("rest", rest)
      end
    else
      raise not_yet_impl("set src_val", rest)
    end

  case
  when _match_vram_addr(dest)
    vram_addr = _match_vram_addr(dest)
    puts "  set_vram #{vram_addr} #{src_val}"
  when _match_vram_ref(dest)
    vram_addr = _match_vram_ref(dest)
    case
    when lvar_names.include?(vram_addr)
      lvar_addr = to_lvar_addr(lvar_names, vram_addr)
      puts "  set_vram #{lvar_addr} #{src_val}"
    else
      raise not_yet_impl("dest", dest)
    end
  when lvar_names.include?(dest)
    lvar_addr = to_lvar_addr(lvar_names, dest)
    puts "  cp #{src_val} #{lvar_addr}"
  else
    raise not_yet_impl("dest", dest)
  end
end

def codegen_return(lvar_names, stmt_rest)
  retval = stmt_rest[0]

  case retval
  when Integer
    puts "  cp #{retval} reg_a"
  when String
    case
    when _match_vram_ref(retval)
      var_name = _match_vram_ref(retval)
      case
      when lvar_names.include?(var_name)
        lvar_addr = to_lvar_addr(lvar_names, var_name)
        puts "  get_vram #{lvar_addr} reg_a"
      else
        raise not_yet_impl("retval", retval)
      end
    when lvar_names.include?(retval)
      lvar_addr = to_lvar_addr(lvar_names, retval)
      puts "  cp #{lvar_addr} reg_a"
    else
      raise not_yet_impl("retval", retval)
    end
  else
    raise not_yet_impl("retval", retval)
  end
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
  # when "eq"
  #   codegen_expr(fn_arg_names, lvar_names, stmt)
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

def codegen(tree)
  puts "  call main"
  puts "  exit"

  head, *rest = tree
  # assert head == "stmts"
  codegen_top_stmts(rest)
end

# vgtコード読み込み
src = File.read(ARGV[0])

# 構文木に変換
tree = JSON.parse(src)

# コード生成（アセンブリコードに変換）
codegen(tree)
