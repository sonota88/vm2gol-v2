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
    raise msg
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

# arg : int | ident
def _parse_arg
  t = peek()
  $pos += 1

  t.get_value()
end

# args : arg*
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

# func_def: "func" func_name "(" args ")" "{" stmts "}"
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

# var_stmt : "var" var_name ";"
#          | "var" var_name "=" expr ";"
def parse_var
  consume "var"

  case peek(1).value
  when ";" then _parse_var_declare()
  when "=" then _parse_var_init()
  else
    raise panic("Unexpected token", peek(1))
  end
end

def binary_op?(t)
  ["+", "*", "==", "!="].include?(t.value)
end

# expr_factor : "(" expr ")" | int | ident
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
    raise panic("Unexpected token kind", t)
  end
end

# expr : factor
#      | expr binary_operator factor
def parse_expr
  expr = _parse_expr_factor()

  while binary_op?(peek())
    op = peek().value
    $pos += 1

    factor = _parse_expr_factor()
    expr = [op.to_sym, expr, factor]
  end

  expr
end

# set_stmt : "set" var_name "=" expr ";"
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

# funcall : func_name "(" args ")"
def parse_funcall
  t = peek()
  $pos += 1
  func_name = t.value

  consume "("
  args = parse_args()
  consume ")"

  [func_name, *args]
end

# call_stmt : "call" funcall ";"
def parse_call
  consume "call"

  funcall = parse_funcall()

  consume ";"

  [:call, funcall]
end

# call_set_stmt : "call_set" var_name "=" funcall ";"
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

# return_stmt : "return" expr ";"
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

# while_stmt : "while" "(" expr ")" "{" stmts "}"
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

# when_clause : "when" "(" expr ")" "{" stmts "}"
def _parse_when_clause
  consume "when"
  consume "("
  expr = parse_expr()
  consume ")"

  consume "{"
  stmts = parse_stmts()
  consume "}"

  [expr, *stmts]
end

# when_clauses : when_clause*

# case_stmt : "case" when_clauses
def parse_case
  consume "case"

  when_clauses = []

  while peek().value == "when"
    when_clauses << _parse_when_clause()
  end

  [:case, *when_clauses]
end

# vm_comment_stmt : "_cmt" "(" comment ")" ";"
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

# debug_stmt : "_debug" "(" ")" ";"
def parse_debug
  consume "_debug"
  consume "("
  consume ")"
  consume ";"

  [:_debug]
end

# stmt : set_stmt
#      | call_stmt
#      | call_set_stmt
#      | return_stmt
#      | while_stmt
#      | case_stmt
#      | vm_comment_stmt
#      | debug_stmt
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
    raise panic("Unexpected token", t)
  end
end

# stmts : stmt*
def parse_stmts
  stmts = []

  while peek().value != "}"
    stmts << parse_stmt()
  end

  stmts
end

# top_stmts : func_def
def parse_top_stmt
  t = peek()

  case t.value
  when "func" then parse_func()
  else
    raise panic("Unexpected token", t)
  end
end

# top_stmts : top_stmt*
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
rescue => e
  pp_e [$pos, rest_head]
  raise e
end

puts JSON.pretty_generate(tree)
