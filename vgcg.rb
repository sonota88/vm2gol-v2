# coding: utf-8

require "json"

require_relative "common"

$label_id = 0

class Names
  def initialize
    @names = []
  end

  def add(name, size)
    @names << [name, size]
  end

  def include?(target)
    @names.map{ |name, _| name }.include?(target)
  end

  def disp_lvar(target)
    disp = 0
    @names.each { |name, size|
      disp -= size
      break if name == target
    }
    disp
  end

  def disp_fn_arg(target)
    disp = 0
    @names.each { |name, size|
      break if name == target
      disp += size
    }
    disp + 2
  end

  def index(target)
    @names.map{ |name, _| name }.index(target)
  end
end

# --------------------------------

def codegen_var(fn_arg_names, lvar_names, stmt_rest)
  puts "  sub_sp 1"

  if stmt_rest.size == 2
    codegen_set(fn_arg_names, lvar_names, stmt_rest)
  end
end

def codegen_var_array(fn_arg_names, lvar_names, stmt_rest)
  _, size = stmt_rest
  puts "  sub_sp #{size}"
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

    # 式の結果が reg_a に入る
    puts "  # -->> expr"
    codegen_expr(fn_arg_names, lvar_names, cond)
    puts "  # <<-- expr"

    # 式の結果と比較するための値を reg_b に入れる
    puts "  cp 0 reg_b"

    puts "  compare"
    puts "  jump_eq #{label_end_when_head}_#{when_idx}" # 真の場合
    puts "  jump #{label_when_head}_#{when_idx}"        # 偽の場合

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
  puts "  cp 0 reg_b"
  puts "  compare"

  # true の場合ループの本体を実行
  puts "  jump_eq #{label_end}"

  # false の場合ループを抜ける
  puts "  jump #{label_true}"

  puts "label #{label_true}"
  # ループの本体
  codegen_stmts(fn_arg_names, lvar_names, body)

  # ループの先頭に戻る
  puts "  jump #{label_begin}"

  puts "label #{label_end}"
  puts ""
end

def _codegen_expr_addr(fn_arg_names, lvar_names, expr)
  _, arg = expr

  if lvar_names.include?(arg)
    disp = lvar_names.disp_lvar(arg)
    puts "  lea reg_a [bp:#{disp}]  # dest src"
  else
    raise not_yet_impl("arg", arg)
  end
end

def _codegen_expr_deref(fn_arg_names, lvar_names, expr)
  codegen_expr(fn_arg_names, lvar_names, expr[1])

  # reg_a が指すアドレスに入っている値を reg_a に転送
  # （間接参照を辿る操作）
  puts "  cp [reg_a] reg_a"
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

def _codegen_expr_lt
  $label_id += 1
  label_id = $label_id

  label_end  = "end_lt_#{label_id}"
  label_then = "then_#{label_id}"

  puts "  pop reg_b"
  puts "  pop reg_a"

  puts "  compare"
  puts "  jump_g #{label_then}"

  # else
  puts "  cp 0 reg_a"
  puts "  jump #{label_end}"

  # then
  puts "label #{label_then}"
  puts "  cp 1 reg_a"

  puts "label #{label_end}"
end

def _codegen_expr_unary(fn_arg_names, lvar_names, expr)
  operator, *args = expr

  case operator
  when "addr"
    _codegen_expr_addr(fn_arg_names, lvar_names, expr)
  when "deref"
    _codegen_expr_deref(fn_arg_names, lvar_names, expr)
  else
    raise not_yet_impl("expr", expr)
  end
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
  when "lt"  then _codegen_expr_lt()
  else
    raise not_yet_impl("operator", operator)
  end
end

def codegen_expr(fn_arg_names, lvar_names, expr)
  case expr
  when Integer
    puts "  cp #{expr} reg_a"

  when String
    push_arg =
      case
      when fn_arg_names.include?(expr)
        disp = fn_arg_names.disp_fn_arg(expr)
        "[bp:#{disp}]"
      when lvar_names.include?(expr)
        disp = lvar_names.disp_lvar(expr)
        "[bp:#{disp}]"
      else
        raise not_yet_impl("expr", expr)
      end

    puts "  cp #{push_arg} reg_a"

  when Array
    if expr[0] == "funcall"
      codegen_call(fn_arg_names, lvar_names, expr[1..-1])
      return
    end

    case expr.size
    when 2
      _codegen_expr_unary(fn_arg_names, lvar_names, expr)
    when 3
      _codegen_expr_binary(fn_arg_names, lvar_names, expr)
    else
      raise not_yet_impl("expr", expr)
    end

  else
    raise not_yet_impl("expr", expr)
  end
end

def codegen_call(fn_arg_names, lvar_names, stmt_rest)
  fn_name, *fn_args = stmt_rest

  if fn_name == "_debug"
    puts "  _debug"
    return
  elsif fn_name == "_panic"
    puts "  call _panic"
    return
  end

  fn_args.reverse.each do |fn_arg|
    codegen_expr(fn_arg_names, lvar_names, fn_arg)
    puts "  push reg_a"
  end

  codegen_vm_comment("call  #{fn_name}")
  puts "  call #{fn_name}"
  puts "  add_sp #{fn_args.size}"
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

  codegen_expr(fn_arg_names, lvar_names, expr)
  puts "  push reg_a"

  case dest
  when String

    case
    when _match_vram_addr(dest)
      vram_addr = _match_vram_addr(dest)
      puts "  pop reg_a"
      puts "  set_vram #{vram_addr} reg_a"
    when _match_vram_ref(dest)
      vram_addr = _match_vram_ref(dest)
      case
      when lvar_names.include?(vram_addr)
        disp = lvar_names.disp_lvar(vram_addr)
        puts "  pop reg_a"
        puts "  set_vram [bp:#{disp}] reg_a"
      else
        raise not_yet_impl("dest", dest)
      end
    when lvar_names.include?(dest)
      disp = lvar_names.disp_lvar(dest)
      puts "  pop reg_a"
      puts "  cp reg_a [bp:#{disp}]"
    else
      raise not_yet_impl("dest", dest)
    end

  when Array
    if dest[0] == "deref"
      codegen_expr(fn_arg_names, lvar_names, dest[1])
      # => reg_a に dest アドレスが入る

      puts "  pop reg_b"
      puts "  cp reg_b [reg_a]"

    else
      raise not_yet_impl("dest", dest)
    end
  else
    raise not_yet_impl("dest", dest)
  end
end

def codegen_return(fn_arg_names, lvar_names, stmt_rest)
  expr = stmt_rest[0]
  codegen_expr(fn_arg_names, lvar_names, expr);
end

def codegen_vm_comment(comment)
  puts "  _cmt " + comment.gsub(" ", "~")
end

def codegen_stmt(fn_arg_names, lvar_names, stmt)
  stmt_head, *stmt_rest = stmt

  case stmt_head
  when "call"
    codegen_call(fn_arg_names, lvar_names, stmt_rest)
  when "set"
    codegen_set(fn_arg_names, lvar_names, stmt_rest)
  when "return"
    codegen_return(fn_arg_names, lvar_names, stmt_rest)
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

  fn_arg_names = Names.new
  rest[1].each { |fn_arg_name| fn_arg_names.add(fn_arg_name, 1) }

  body = rest[2]

  puts ""
  puts "label #{fn_name}"
  puts "  push bp"
  puts "  cp sp bp"

  puts ""
  puts "  # -->> #{fn_name} body"

  lvar_names = Names.new

  body.each do |stmt|
    case stmt[0]
    when "var"
      _, *stmt_rest = stmt
      lvar_names.add(stmt_rest[0], 1)
      codegen_var(fn_arg_names, lvar_names, stmt_rest)
    when "var_array"
      _, *stmt_rest = stmt
      lvar_name, size = stmt_rest
      lvar_names.add(lvar_name, size)
      codegen_var_array(fn_arg_names, lvar_names, stmt_rest)
    else
      codegen_stmt(fn_arg_names, lvar_names, stmt)
    end
  end

  puts "  # <<-- #{fn_name} body"

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

def codegen_builtin_getchar
  puts "label getchar"
  puts "  push bp"
  puts "  cp sp bp"
  puts "  getchar reg_a"
  puts "  cp bp sp"
  puts "  pop bp"
  puts "  ret"
end

def codegen_builtin_putchar
  puts "label putchar"
  puts "  push bp"
  puts "  cp sp bp"
  puts "  cp [bp:2] reg_a"
  puts "  putchar reg_a"
  puts "  cp bp sp"
  puts "  pop bp"
  puts "  ret"
end

def codegen_builtin_get_sp
  puts "label get_sp"
  puts "  push bp"
  puts "  cp sp bp"

  puts "  cp sp reg_a"

  puts "  cp bp sp"
  puts "  pop bp"
  puts "  ret"
end

def codegen_builtin_panic
  puts "label _panic"
  "PANIC\n".each_char do |c|
    puts "  putchar #{c.ord}"
  end
  puts "  exit"
end

def codegen_builtin_set_vram
  puts "label set_vram"
  puts "  push bp"
  puts "  cp sp bp"

  puts "  set_vram [bp:2] [bp:3]" # vram_addr value

  puts "  cp bp sp"
  puts "  pop bp"
  puts "  ret"
end

def codegen(tree)
  puts "  call main"
  puts "  exit"

  puts ""
  codegen_builtin_getchar()
  puts ""
  codegen_builtin_putchar()
  puts ""
  codegen_builtin_get_sp()
  puts ""
  codegen_builtin_panic()
  puts ""
  codegen_builtin_set_vram()

  head, *rest = tree
  # assert head == "top_stmts"
  codegen_top_stmts(rest)
end

src = File.read(ARGV[0])

tree = JSON.parse(src)

codegen(tree)
