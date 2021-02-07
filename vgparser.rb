# coding: utf-8

require "json"
require "pp"

require_relative "./common"

$tokens = nil
$pos = nil

def read_tokens(src)
  tokens = []

  src.each_line do |line|
    token = Token.from_line(line)
    tokens << token unless token.nil?
  end

  tokens
end

# --------------------------------

class ParseError < StandardError; end

def rest_head
  $tokens[$pos ... $pos + 8]
    .map { |t| format("%s<%s>", t.type, t.value) }
end

def peek(offset = 0)
  $tokens[$pos + offset]
end

def dump_state(msg = nil)
  pp_e [
    msg,
    $pos,
    rest_head
  ]
end

def assert_value(pos, exp)
  t = peek()

  if t.value != exp
    msg = format(
      "Assertion failed: expected(%s) actual(%s)",
      exp.inspect,
      t.inspect
    )
    raise ParseError, msg
  end
end

def consume(str)
  assert_value($pos, str)
  $pos += 1
end

def end?
  $tokens.size <= $pos
end

# --------------------------------

def _parse_arg
  t = peek()

  if t.type == :ident
    $pos += 1
    t.value
  else
    raise ParseError, t
  end
end

def _parse_args_first
  return nil if peek().value == ")"

  _parse_arg()
end

def _parse_args_rest
  return nil if peek().value == ")"

  consume(",")

  _parse_arg()
end

def parse_args
  args = []

  first_arg = _parse_args_first()
  if first_arg.nil?
    return args
  else
    args << first_arg
  end

  loop do
    rest_arg = _parse_args_rest()
    if rest_arg.nil?
      break
    else
      args << rest_arg
    end
  end

  args
end

# --------------------------------

def _parse_exprs_rest
  return nil if peek().value == ")"

  consume(",")
  parse_expr()
end

def parse_exprs
  exprs = []

  if peek().value == ")"
    return exprs
  end

  first_arg = parse_expr()
  if first_arg.nil?
    return exprs
  else
    exprs << first_arg
  end

  loop do
    rest_arg = _parse_exprs_rest()
    if rest_arg.nil?
      break
    else
      exprs << rest_arg
    end
  end

  exprs
end

# --------------------------------

def parse_func
  consume "def"

  t = peek()
  $pos += 1
  func_name = t.value

  consume "("
  args = parse_args()
  consume ")"

  stmts = []
  loop do
    t = peek()
    break if t.value == "end"

    stmts <<
      if t.value == "var"
        parse_var()
      else
        parse_stmt()
      end
  end

  consume "end"

  [:func, func_name, args, stmts]
end

def parse_var_declare
  t = peek()
  $pos += 1
  var_name = t.value

  consume ";"

  [:var, var_name]
end

def parse_var_init
  t = peek()
  $pos += 1
  var_name = t.value

  consume "="

  expr = parse_expr()

  consume ";"

  [:var, var_name, expr]
end

def parse_var_array
  consume "["
  t = peek()
  $pos += 1
  size = t.value.to_i
  consume "]"

  var_name = peek().value
  $pos += 1

  consume ";"

  [:var_array, var_name, size]
end

def parse_var
  consume "var"

  if peek().value == "["
    parse_var_array()
  else
    t = peek(1)

    if t.value == ";"
      parse_var_declare()
    elsif t.value == "="
      parse_var_init()
    else
      raise ParseError, t
    end
  end
end

def parse_expr_right(expr_l)
  t = peek()

  if t.value == ";" || t.value == ")" || t.value == "]" || t.value == ","
    return expr_l
  end

  case t.value
  when "+"
    consume "+"
    expr_r = parse_expr()
    [:+, expr_l, expr_r]

  when "*"
    consume "*"
    expr_r = parse_expr()
    [:*, expr_l, expr_r]

  when "=="
    consume "=="
    expr_r = parse_expr()
    [:eq, expr_l, expr_r]

  when "!="
    consume "!="
    expr_r = parse_expr()
    [:neq, expr_l, expr_r]

  when "<"
    consume "<"
    expr_r = parse_expr()
    [:lt, expr_l, expr_r]

  else
    raise ParseError, t
  end
end

def parse_expr_addr
  consume "&"
  var_name = peek().value
  $pos += 1

  ["addr", var_name]
end

def parse_deref
  consume "*"
  consume "("
  expr = parse_expr()
  consume ")"

  ["deref", expr]
end

def parse_expr
  t_left = peek()

  case t_left.value
  when "("
    consume "("
    expr_l = parse_expr()
    consume ")"

    return parse_expr_right(expr_l)
  when "&"
    expr_l = parse_expr_addr()
    return parse_expr_right(expr_l)
  when "*"
    expr_l = parse_deref()
    return parse_expr_right(expr_l)
  end

  if t_left.type == :int
    $pos += 1

    expr_l = t_left.value.to_i

    parse_expr_right(expr_l)

  elsif t_left.type == :ident

    if peek(1).value == "("
      fn_name, *args = parse_funcall()
      expr_l = [:funcall, fn_name, *args]
      parse_expr_right(expr_l)
    else
      $pos += 1
      expr_l = t_left.value
      parse_expr_right(expr_l)
    end
  else
    raise ParseError, t_left
  end
end

def parse_set
  if peek().value == "*"
    var_name = parse_deref()
  else
    t = peek()
    $pos += 1
    var_name = t.value
  end

  consume "="

  expr = parse_expr()

  consume ";"

  [:set, var_name, expr]
end

def parse_funcall
  t = peek()
  $pos += 1
  func_name = t.value

  consume "("
  args = parse_exprs()
  consume ")"

  [func_name, *args]
end

def parse_call
  func_name, *args = parse_funcall()

  consume ";"

  [:call, func_name, *args]
end

def parse_return
  consume "return"

  t = peek()

  if t.value == ";"
    consume ";"
    [:return]
  else
    expr = parse_expr()
    consume ";"
    [:return, expr]
  end
end

def _parse_when_clause
  t = peek()
  return nil if t.value == "end"

  case t.value
  when "when"
    consume "when"
    consume "("
    expr = parse_expr()
    consume ")"
  when "else"
    consume "else"
    expr = [:eq, 0, 0]
  else
    raise not_yet_impl("t", t)
  end

  stmts = parse_stmts()

  [expr, *stmts]
end

def parse_case
  consume "case"

  when_clauses = []

  loop do
    when_clause = _parse_when_clause()
    if when_clause.nil?
      break
    else
      when_clauses << when_clause
    end
  end

  if when_clauses.empty?
    raise ParseError, "At least one when clause is required"
  end

  consume "end"

  [:case, *when_clauses]
end

def parse_while
  consume "while"

  consume "("
  expr = parse_expr()
  consume ")"

  stmts = parse_stmts()
  consume "end"

  [:while, expr, stmts]
end

def parse_vm_comment
  consume "_cmt"
  consume "("

  t = peek()
  $pos += 1
  comment = t.value

  consume ")"
  consume ";"

  [:_cmt, comment]
end

def parse_vm_debug
  consume "_debug"
  consume "("
  consume ")"
  consume ";"

  [:call, "_debug"]
end

def parse_vm_panic
  consume "_panic"
  consume "("
  consume ")"
  consume ";"

  [:call, "_panic"]
end

def parse_stmt
  t = peek()

  case t.value
  when "return"   then parse_return()
  when "while"    then parse_while()
  when "case"     then parse_case()
  when "_cmt"     then parse_vm_comment()
  when "_debug"   then parse_vm_debug()
  when "_panic"   then parse_vm_panic()
  else
    if t.type == :ident && peek(1).is(:sym, "(")
      parse_call()
    else
      parse_set()
    end
  end
end

def parse_stmts
  stmts = []

  loop do
    if (
      peek().value == "end" ||
      peek().value == "when" ||
      peek().value == "else"
    )
      break
    end

    stmts << parse_stmt()
  end

  stmts
end

def parse_top_stmt
  t = peek()

  case t.value
  when "def" then parse_func()
  else
    raise ParseError, "Unexpected token (#{t.inspect})"
  end
end

def parse_top_stmts
  stmts = []

  loop do
    break if end?()

    stmts << parse_top_stmt()
  end

  stmts
end

def parse
  top_stmts = parse_top_stmts()
  [:top_stmts, *top_stmts]
end

# --------------------------------

in_file = ARGV[0]

$tokens = read_tokens(File.read(in_file))
$pos = 0

begin
  tree = parse()
rescue ParseError => e
  dump_state()
  raise e
end

puts JSON.pretty_generate(tree)
