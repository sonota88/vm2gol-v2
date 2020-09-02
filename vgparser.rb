# coding: utf-8

require "json"
require "pp"

require_relative "./common"

class Token
  attr_reader :type, :value

  # type:
  #   str:   string
  #   kw:    keyword
  #   int:   integer
  #   sym:   symbol
  #   ident: identifier
  def initialize(type, value)
    @type = type
    @value = value
  end
end

def tokenize(src)
  tokens = []

  pos = 0

  while pos < src.size
    rest = src[pos .. -1]

    case rest
    when /\A([ \n]+)/
      str = $1
      pos += str.size

    when %r{\A(//.*)$}
      str = $1
      pos += str.size

    when /\A"(.*)"/
      str = $1
      tokens << Token.new(:str, str)
      pos += str.size + 2

    when /\A(func|set|var|call_set|call|return|case|while|_cmt)[^a-z_]/
      str = $1
      tokens << Token.new(:kw, str)
      pos += str.size

    when /\A(-?[0-9]+)/
      str = $1
      tokens << Token.new(:int, str.to_i)
      pos += str.size

    when /\A(==|!=|[(){}=;+*,])/
      str = $1
      tokens << Token.new(:sym, str)
      pos += str.size

    when /\A([a-z_][a-z0-9_\[\]]*)/
      str = $1
      tokens << Token.new(:ident, str)
      pos += str.size

    else
      p_e rest[0...100]
      raise "must not happen"

    end
  end

  tokens
end

# --------------------------------

class Parser
  class ParseError < StandardError; end

  def initialize(tokens)
    @tokens = tokens
    @pos = 0
  end

  def rest_head
    @tokens[@pos ... @pos + 8]
      .map { |t| format("%s<%s>", t.type, t.value) }
  end

  def peek
    @tokens[@pos]
  end

  def dump_state(msg = nil)
    pp_e [
      msg,
      @pos,
      rest_head
    ]
  end

  def assert_value(pos, exp)
    t = @tokens[pos]

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
    assert_value(@pos, str)
    @pos += 1
  end

  # --------------------------------

  def _parse_arg
    t = peek()

    if t.type == :ident
      @pos += 1
      t.value
    elsif t.type == :int
      @pos += 1
      t.value
    else
      raise ParseError
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

  def parse_func
    consume "func"

    t = peek()
    @pos += 1
    func_name = t.value

    consume "("
    args = parse_args()
    consume ")"

    consume "{"
    stmts = parse_stmts()
    consume "}"

    [:func, func_name, args, stmts]
  end

  def parse_var_declare
    t = peek()
    @pos += 1
    var_name = t.value

    consume ";"

    [:var, var_name]
  end

  def parse_var_init
    t = peek()
    @pos += 1
    var_name = t.value

    consume "="

    expr = parse_expr()

    consume ";"

    [:var, var_name, expr]
  end

  def parse_var
    consume "var"

    t = @tokens[@pos + 1]

    if t.value == ";"
      parse_var_declare()
    elsif t.value == "="
      parse_var_init()
    else
      raise ParseError
    end
  end

  def parse_expr_right(expr_l)
    t = peek()

    if t.value == ";" || t.value == ")"
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

    else
      raise ParseError
    end
  end

  def parse_expr
    t_left = peek()

    if t_left.value == "("
      consume "("
      expr_l = parse_expr()
      consume ")"

      return parse_expr_right(expr_l)
    end

    if t_left.type == :int || t_left.type == :ident
      @pos += 1

      expr_l = t_left.value
      parse_expr_right(expr_l)

    else
      raise ParseError
    end
  end

  def parse_set
    consume "set"

    t = peek()
    @pos += 1
    var_name = t.value

    consume "="

    expr = parse_expr()

    consume ";"

    [:set, var_name, expr]
  end

  def parse_call
    consume "call"

    t = peek()
    @pos += 1
    func_name = t.value

    consume "("
    args = parse_args()
    consume ")"

    consume ";"

    [:call, func_name, *args]
  end

  def parse_funcall
    t = peek()
    @pos += 1
    func_name = t.value

    consume "("
    args = parse_args()
    consume ")"

    [func_name, *args]
  end

  def parse_call_set
    consume "call_set"

    t = peek()
    @pos += 1
    var_name = t.value

    consume "="

    expr = parse_funcall()

    consume ";"

    [:call_set, var_name, expr]
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
    return nil if t.value == "}"

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

    consume "}"

    [:case, *when_clauses]
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

  def parse_vm_comment
    consume "_cmt"
    consume "("

    t = peek()
    @pos += 1
    comment = t.value

    consume ")"
    consume ";"

    [:_cmt, comment]
  end

  def parse_stmt
    t = peek()

    return nil if t.value == "}"

    case t.value
    when "func"     then parse_func()
    when "var"      then parse_var()
    when "set"      then parse_set()
    when "call"     then parse_call()
    when "call_set" then parse_call_set()
    when "return"   then parse_return()
    when "while"    then parse_while()
    when "case"     then parse_case()
    when "_cmt"     then parse_vm_comment()
    else
      raise ParseError
    end
  end

  def end?
    @tokens.size <= @pos
  end

  def parse_stmts
    stmts = []

    loop do
      break if end?()

      stmt = parse_stmt()
      break if stmt.nil?

      stmts << stmt
    end

    stmts
  end

  def parse
    stmts = parse_stmts()
    [:stmts, *stmts]
  end
end

# --------------------------------

if $PROGRAM_NAME == __FILE__
  in_file = ARGV[0]
  tokens = tokenize(File.read(in_file))

  parser = Parser.new(tokens)

  begin
    tree = parser.parse()
  rescue Parser::ParseError => e
    parser.dump_state()
    raise e
  end

  puts JSON.pretty_generate(tree)
end
