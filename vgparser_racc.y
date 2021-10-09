# -*- mode: ruby -*-

class Parser

  prechigh
    left "+" "*"
  preclow

rule

  program:
    top_stmts
      {
        top_stmts = val[0]
        result = ["top_stmts", *top_stmts]
      }

  top_stmts:
    top_stmt
      {
        top_stmt = val[0]
        result = [top_stmt]
      }
  | top_stmts top_stmt
      {
        top_stmts, top_stmt = val
        result = [*top_stmts, top_stmt]
      }

  top_stmt:
    func_def

  func_def:
    "func" IDENT "(" args ")" "{" stmts "}"
      {
        _, fn_name, _, args, _, _, stmts, _, = val
        result = ["func", fn_name, args, stmts]
      }

  args:
    # nothing
      {
        result = []
      }
  | arg
      {
        arg = val[0]
        result = [arg]
      }
  | args "," arg
      {
        args, _, arg = val
        result = [*args, arg]
      }

  arg:
    IDENT | INT

  stmts:
    # nothing
      {
        result = []
      }
  | stmt
      {
        stmt = val[0]
        result = [stmt]
      }
  | stmts stmt
      {
        stmts, stmt = val
        result = [*stmts, stmt]
      }

  stmt:
    stmt_var
  | stmt_set
  | stmt_return
  | stmt_call
  | stmt_call_set
  | stmt_while
  | stmt_case
  | stmt_vm_comment
  | stmt_debug

  stmt_var:
    "var" IDENT ";"
      {
        _, ident, _ = val
        result = ["var", ident]
      }
  | "var" IDENT "=" expr ";"
      {
        _, ident, _, expr = val
        result = ["var", ident, expr]
      }

  stmt_set:
    "set" IDENT "=" expr ";"
      {
        _, ident, _, expr = val
        result = ["set", ident, expr]
      }

  stmt_return:
    "return" ";"
      {
        result = ["return"]
      }
  | "return" expr ";"
      {
        _, expr, _ = val
        result = ["return", expr]
      }

  stmt_call:
    "call" IDENT "(" args ")" ";"
      {
        _, fn_name, _, args, _ = val
        funcall = [fn_name, *args]
        result = ["call", *funcall]
      }

  stmt_call_set:
    "call_set" IDENT "=" IDENT "(" args ")" ";"
      {
        _, var_name, _, fn_name, _, args, _ = val
        funcall = [fn_name, *args]
        result = ["call_set", var_name, funcall]
      }

  stmt_while:
    "while" "(" expr ")" "{" stmts "}"
      {
        _, _, expr, _, _, stmts, _ = val
        result = ["while", expr, stmts]
      }

  stmt_case:
    "case" when_clauses
      {
        _, when_clauses = val
        result = ["case", *when_clauses]
      }

  when_clauses:
    when_clause
      {
        when_clause = val[0]
        result = [when_clause]
      }
  | when_clauses when_clause
      {
        when_clauses, when_clause = val
        result = [*when_clauses, when_clause]
      }

  when_clause:
    "when" "(" expr ")" "{" stmts "}"
      {
        _, _, expr, _, _, stmts, _ = val
        result = [expr, *stmts]
      }

  stmt_vm_comment:
    "_cmt" "(" STR ")" ";"
      {
        _, _, str, _ = val
        result = ["_cmt", str]
      }

  stmt_debug:
    "_debug" "(" ")" ";"
      {
        result = ["_debug"]
      }

  expr:
    INT
      {
        result = val[0]
      }
  | IDENT
      {
        result = val[0]
      }
  | expr "+" expr
      {
        term_l, _, term_r = val
        result = ["+", term_l, term_r]
      }
  | expr "*" expr
      {
        term_l, _, term_r = val
        result = ["*", term_l, term_r]
      }
  | expr "==" expr
      {
        term_l, _, term_r = val
        result = ["==", term_l, term_r]
      }
  | expr "!=" expr
      {
        term_l, _, term_r = val
        result = ["!=", term_l, term_r]
      }
  | "(" expr ")"
      {
        _, expr, _ = val
        result = expr
      }

end

---- header

require "json"
require_relative "common"

---- inner

# def initialize
#   # parser.rb を使ったときにデバッグ情報を出力する
#   @yydebug = true
#   # デバッグ情報の出力先をファイルに変更
#   @racc_debug_out = File.open("debug.log", "wb")

#   @racc_stack_out = File.open("stack.log", "wb")
# end

# # Override Racc::Parser#racc_print_stacks
# def racc_print_stacks(tstack, vstack)
#   super(tstack, vstack)
#   stack = tstack.zip(vstack).map { |t, v| [racc_token2str(t), v] }
#   @racc_stack_out.puts JSON.generate(stack)
# end

def next_token
  @tokens.shift
end

def to_token(line)
  token = Token.from_line(line)
  return nil if token.nil?

  if token.kind == :int
    Token.new(token.kind, token.value.to_i)
  else
    token
  end
end

def read_tokens(src)
  tokens = []

  src.each_line do |line|
    token = to_token(line)
    next if token.nil?

    tokens << token
  end

  tokens
end

def to_racc_token(token)
  kind =
    case token.kind
    when :ident then :IDENT
    when :int   then :INT
    when :str   then :STR
    else
      token.value
    end

  [kind, token.value]
end

def parse(src)
  tokens = read_tokens(src)
  @tokens = tokens.map { |token| to_racc_token(token) }
  @tokens << [false, false]

  do_parse()
end

---- footer

if $0 == __FILE__
  ast = Parser.new.parse(ARGF.read)
  puts JSON.pretty_generate(ast)
end
