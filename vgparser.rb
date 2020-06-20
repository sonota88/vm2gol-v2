# coding: utf-8

require "json"
require "pp"

require_relative "./common"

class Token
  attr_reader :type, :value

  def initialize(type, value)
    @type = type
    @value = value
  end
end

class Parser
  class ParseError < StandardError; end

  def initialize(tokens)
    @tokens = tokens
    @pos = 0
  end

  def rest_head
    @tokens[@pos ... @pos + 8]
      .map { |t| "%s<%s>" % [t.type, t.value] }
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
      raise ParseError, "Assertion failed: expected(%s) actual(%s)" % [
              exp.inspect,
              t.inspect
            ]
    end
  end

  def consume(str)
    assert_value(@pos, str)
    @pos += 1
  end

  # --------------------------------

  def parse_args
    args = []

    loop do
      t = @tokens[@pos]
      break if t.value == ")"

      if t.type == :ident
        @pos += 1
        name = t.value
        args << name
      elsif t.type == :int
        @pos += 1
        val = t.value
        args << val
      elsif t.value == ","
        @pos += 1
      else
        dump_state()
        raise ParseError
      end
    end

    args
  end

  def parse_func
    consume "func"

    t = @tokens[@pos]
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
    t = @tokens[@pos]
    @pos += 1
    var_name = t.value

    consume ";"

    [:var, var_name]
  end

  def parse_var_init
    t = @tokens[@pos]
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
      dump_state()
      raise ParseError
    end
  end

  def parse_expr_right(expr_l)
    t = @tokens[@pos]

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
      dump_state()
      raise ParseError
    end
  end

  def parse_expr
    t_left = @tokens[@pos]

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
      dump_state()
      raise ParseError
    end
  end

  def parse_set
    consume "set"

    t = @tokens[@pos]
    @pos += 1
    var_name = t.value

    consume "="

    expr = parse_expr()

    consume ";"

    [:set, var_name, expr]
  end

  def parse_call
    consume "call"

    t = @tokens[@pos]
    @pos += 1
    func_name = t.value

    consume "("
    args = parse_args()
    consume ")"

    consume ";"

    [:call, func_name, *args]
  end

  def parse_funcall
    t = @tokens[@pos]
    @pos += 1
    func_name = t.value

    consume "("
    args = parse_args()
    consume ")"

    [func_name, *args]
  end

  def parse_call_set
    consume "call_set"

    t = @tokens[@pos]
    @pos += 1
    var_name = t.value

    consume "="

    expr = parse_funcall()

    consume ";"

    [:call_set, var_name, expr]
  end

  def parse_return
    consume "return"

    t = @tokens[@pos]

    if t.value == ";"
      consume ";"
      [:return]
    else
      expr = parse_expr()
      consume ";"
      [:return, expr]
    end
  end

  def parse_case
    consume "case"

    consume "{"

    when_clauses = []

    loop do
      t = @tokens[@pos]
      break if t.value == "}"

      consume "("
      expr = parse_expr()
      consume ")"

      consume "{"
      stmts = parse_stmts()
      consume "}"

      when_clauses << [expr, *stmts]
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

  def parse__cmt
    consume "_cmt"
    consume "("

    t = @tokens[@pos]
    @pos += 1
    comment = t.value

    consume ")"
    consume ";"

    [:_cmt, comment]
  end

  def parse_stmt
    t = @tokens[@pos]

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
    when "_cmt"     then parse__cmt()
    else
      dump_state()
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
      tokens << Token.new(:string, str)
      pos += str.size + 2

    when /\A(func|set|var|call_set|call|return|case|while|_cmt)[^a-z_]/
      str = $1
      tokens << Token.new(:reserved, str)
      pos += str.size

    when /\A(-?[0-9]+)/
      str = $1
      tokens << Token.new(:int, str.to_i)
      pos += str.size

    when /\A(==|!=|[\(\)\{\}=;\+\*,])/
      str = $1
      tokens << Token.new(:symbol, str)
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

if $PROGRAM_NAME == __FILE__
  in_file = ARGV[0]
  tokens = tokenize(File.read(in_file))

  parser = Parser.new(tokens)
  tree = parser.parse()

  puts JSON.pretty_generate(tree)
end
