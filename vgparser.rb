require "json"

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
    .map { |t| format("%s<%s>", t.kind, t.value) }
end

def peek(offset = 0)
  $tokens[$pos + offset]
end

def assert_value(exp)
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
  assert_value(str)
  $pos += 1
end

def end?
  $tokens.size <= $pos
end

# --------------------------------

def _parse_arg
  t = peek()
  $pos += 1

  t.get_value()
end

def parse_args
  args = []

  return args if peek().value == ")"

  args << _parse_arg()

  while peek().value == ","
    consume ","
    args << _parse_arg()
  end

  args
end

def parse_func
  consume "func"

  t = peek()
  $pos += 1
  func_name = t.value

  consume "("
  args = parse_args()
  consume ")"

  consume "{"

  stmts = []
  while peek().value != "}"
    stmts <<
      if peek().value == "var"
        parse_var()
      else
        parse_stmt()
      end
  end

  consume "}"

  [:func, func_name, args, stmts]
end

def _parse_var_declare
  t = peek()
  $pos += 1
  var_name = t.value

  consume ";"

  [:var, var_name]
end

def _parse_var_init
  t = peek()
  $pos += 1
  var_name = t.value

  consume "="

  expr = parse_expr()

  consume ";"

  [:var, var_name, expr]
end

def parse_var
  consume "var"

  t = peek(1)

  if t.value == ";"
    _parse_var_declare()
  elsif t.value == "="
    _parse_var_init()
  else
    raise ParseError
  end
end

def binary_op?(t)
  ["+", "*", "==", "!="].include?(t.value)
end

def _parse_expr_factor
  t = peek()

  case t.kind
  when :sym
    consume "("
    expr = parse_expr()
    consume ")"
    expr
  when :int, :ident
    $pos += 1
    t.get_value()
  else
    raise ParseError
  end
end

def parse_expr
  expr = _parse_expr_factor()

  while binary_op?(peek())
    op = peek().value
    $pos += 1

    expr_r = _parse_expr_factor()
    expr = [op.to_sym, expr, expr_r]
  end

  expr
end

def parse_set
  consume "set"

  t = peek()
  $pos += 1
  var_name = t.value

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
  args = parse_args()
  consume ")"

  [func_name, *args]
end

def parse_call
  consume "call"

  funcall = parse_funcall()

  consume ";"

  [:call, *funcall]
end

def parse_call_set
  consume "call_set"

  t = peek()
  $pos += 1
  var_name = t.value

  consume "="

  funcall = parse_funcall()

  consume ";"

  [:call_set, var_name, funcall]
end

def parse_return
  consume "return"

  if peek().value == ";"
    consume ";"
    [:return]
  else
    expr = parse_expr()
    consume ";"
    [:return, expr]
  end
end

def parse_while
  consume "while"

  consume "("
  expr = parse_expr()
  consume ")"

  consume "{"
  stmts = parse_stmts()
  consume "}"

  [:while, expr, stmts]
end

def _parse_when_clause
  consume "("
  expr = parse_expr()
  consume ")"

  consume "{"
  stmts = parse_stmts()
  consume "}"

  [expr, *stmts]
end

def parse_case
  consume "case"

  consume "{"

  when_clauses = []

  while peek().value != "}"
    when_clauses << _parse_when_clause()
  end

  consume "}"

  [:case, *when_clauses]
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

def parse_debug
  consume "_debug"
  consume "("
  consume ")"
  consume ";"

  [:_debug]
end

def parse_stmt
  t = peek()

  case t.value
  when "set"      then parse_set()
  when "call"     then parse_call()
  when "call_set" then parse_call_set()
  when "return"   then parse_return()
  when "while"    then parse_while()
  when "case"     then parse_case()
  when "_cmt"     then parse_vm_comment()
  when "_debug"   then parse_debug()
  else
    raise ParseError, "Unexpected token (#{t.inspect})"
  end
end

def parse_stmts
  stmts = []

  while peek().value != "}"
    stmts << parse_stmt()
  end

  stmts
end

def parse_top_stmt
  t = peek()

  case t.value
  when "func" then parse_func()
  else
    raise ParseError, "Unexpected token (#{t.inspect})"
  end
end

def parse_top_stmts
  stmts = []

  while !(end?())
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
  pp_e [$pos, rest_head]
  raise e
end

puts JSON.pretty_generate(tree)
