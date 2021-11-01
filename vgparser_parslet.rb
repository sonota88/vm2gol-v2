require "json"
require "pp"
require "parslet"

class Parser < Parslet::Parser
  rule(:comment) {
    str("//") >>
    (str("\n").absent? >> any).repeat >>
    str("\n")
  }

  rule(:spaces) {
    (
      match('[ \n]') | comment
    ).repeat(1)
  }
  rule(:spaces?) { spaces.maybe }

  rule(:lparen   ) { str("(") >> spaces? }
  rule(:rparen   ) { str(")") >> spaces? }
  rule(:lbrace   ) { str("{") >> spaces? }
  rule(:rbrace   ) { str("}") >> spaces? }
  rule(:comma    ) { str(",") >> spaces? }
  rule(:semicolon) { str(";") >> spaces? }
  rule(:equal    ) { str("=") >> spaces? }

  rule(:ident) {
    (
      match('[_a-z]') >> match('[_a-z0-9]').repeat
    ).as(:ident_) >> spaces?
  }

  rule(:int) {
    (
      str("-").maybe >>
      (
        (match('[1-9]') >> match('[0-9]').repeat) |
        str("0")
      )
    ).as(:int_) >> spaces?
  }

  rule(:string) {
    str('"') >>
    ((str('"').absent? >> any).repeat).as(:string_) >>
    str('"') >> spaces?
  }

  rule(:arg) { ident | int }
  rule(:args) {
    (
      (
        arg.as(:arg_) >>
        (comma >> arg.as(:arg_)).repeat
      ).maybe
    ).as(:args_)
  }

  rule(:factor) {
    (
      lparen >> expr.as(:factor_expr_) >> rparen
    ).as(:factor_) |
    int |
    ident
  }

  rule(:binop) {
    (
      str("+") | str("*") | str("==") | str("!=")
    ).as(:binop_) >> spaces?
  }

  rule(:expr) {
    (
      factor.as(:lhs_) >>
      (binop.as(:binop_) >> factor.as(:rhs_)).repeat(1)
    ).as(:expr_) |
    factor
  }

  rule(:stmt_return) {
    (
      str("return") >>
      (spaces >> expr.as(:return_expr_)).maybe >>
      semicolon
    ).as(:stmt_return_)
  }

  rule(:stmt_var) {
    (
      str("var") >> spaces >> ident.as(:var_name_) >>
      (equal >> expr.as(:expr_)).maybe >>
      semicolon
    ).as(:stmt_var_)
  }

  rule(:stmt_set) {
    (
      str("set") >> spaces >>
      ident.as(:var_name_) >> equal >> expr.as(:expr_) >>
      semicolon
    ).as(:stmt_set_)
  }

  rule(:funcall) {
    (
      ident.as(:fn_name_) >>
      lparen >> args.as(:args_) >> rparen
    ).as(:funcall_)
  }

  rule(:stmt_call) {
    (
      str("call") >> spaces >>
      funcall >>
      semicolon
    ).as(:stmt_call_)
  }

  rule(:stmt_call_set) {
    (
      str("call_set") >> spaces >>
      ident.as(:var_name_) >> equal >> funcall.as(:funcall_) >>
      semicolon
    ).as(:stmt_call_set_)
  }

  rule(:stmt_while) {
    (
      str("while") >> spaces? >>
      lparen >> expr.as(:expr_) >> rparen >>
      lbrace >> stmts.as(:stmts_) >> rbrace
    ).as(:stmt_while_)
  }

  rule(:when_clause) {
    (
      str("when") >> spaces? >>
      lparen >> expr.as(:expr_) >> rparen >>
      lbrace >> stmts.as(:stmts_) >> rbrace
    ).as(:when_clause_)
  }

  rule(:stmt_case) {
    (
      str("case") >> spaces >>
      when_clause.repeat.as(:when_clauses_)
    ).as(:stmt_case_)
  }

  rule(:stmt_vm_comment) {
    (
      str("_cmt") >>
      lparen >> string.as(:cmt_) >> rparen >>
      semicolon
    ).as(:stmt_vm_comment_)
  }

  rule(:stmt_debug) {
    (
      str("_debug") >> lparen >> rparen >> semicolon
    ).as(:stmt_debug_)
  }

  rule(:stmt) {
    stmt_return     |
    stmt_var        |
    stmt_set        |
    stmt_call       |
    stmt_call_set   |
    stmt_while      |
    stmt_case       |
    stmt_vm_comment |
    stmt_debug
  }

  rule(:stmts) {
    (stmt.repeat).as(:stmts_)
  }

  rule(:func_def) {
    (
      str("func") >> spaces >>
      ident.as(:fn_name_) >>
      lparen >> args.as(:fn_args_) >> rparen >>
      lbrace >> stmts.as(:fn_stmts_) >> rbrace
    ).as(:func_def_)
  }

  rule(:top_stmt) {
    func_def.as(:top_stmt_)
  }

  rule(:program) {
    spaces? >> (top_stmt.repeat).as(:top_stmts_)
  }

  root(:program)
end

class Transform < Parslet::Transform
  rule(int_: simple(:x)) { x.to_i }
  rule(ident_: simple(:x)) { x.to_s }
  rule(string_: simple(:x)) { x.to_s }

  rule(args_: subtree(:st)) {
    xs =
      case st
      when nil   then []
      when Array then st
      when Hash  then [st]
      else
        raise "must not happen (#{st.class})"
      end

    xs.map { |x| x[:arg_] }
  }

  rule(stmt_return_: { return_expr_: subtree(:e) }) {
    [:return, e]
  }
  rule(stmt_return_: simple(:e)) {
    [:return]
  }

  rule(binop_: simple(:op)) {
    op.to_s
  }

  rule(expr_: subtree(:st)) {
    case st
    when Array
      head, *rest = st
      expr = head[:lhs_]
      rest.each { |op_rhs|
        expr = [
          op_rhs[:binop_],
          expr,
          op_rhs[:rhs_]
        ]
      }
      expr
    when Hash
      [st[:binop_], st[:lhs_], st[:rhs_]]
    else
      raise "must not happen (#{st.class})"
    end
  }

  rule(factor_: subtree(:st)) {
    st[:factor_expr_]
  }

  rule(stmt_var_: { var_name_: simple(:var_name), expr_: subtree(:e) }) {
    [:var, var_name, e]
  }
  rule(stmt_var_: { var_name_: simple(:var_name) }) {
    [:var, var_name]
  }

  rule(stmt_set_: subtree(:st)) {
    [:set, st[:var_name_], st[:expr_]]
  }

  rule(funcall_: subtree(:st)) {
    args = st[:args_]
    [st[:fn_name_], *args]
  }

  rule(stmt_call_: subtree(:st)) {
    [:call, *st]
  }

  rule(stmt_call_set_: subtree(:st)) {
    [:call_set, st[:var_name_], st[:funcall_]]
  }

  rule(stmt_while_: subtree(:st)) {
    stmts = st[:stmts_]
    [:while, st[:expr_], stmts]
  }

  rule(stmts_: subtree(:st)) {
    st
  }

  rule(when_clause_: subtree(:st)) {
    [st[:expr_]] + st[:stmts_]
  }

  rule(stmt_case_: subtree(:st)) {
    [:case] + st[:when_clauses_]
  }

  rule(stmt_vm_comment_: subtree(:st)) {
    [:_cmt, st[:cmt_]]
  }

  rule(stmt_debug_: subtree(:st)) {
    [:_debug]
  }

  rule(
    func_def_: {
      fn_name_: simple(:name),
      fn_args_: subtree(:args),
      fn_stmts_: subtree(:stmts)
    }
  ) {
    [:func, name, args, stmts]
  }

  rule(top_stmts_: subtree(:st)) {
    [:top_stmts] + st
  }

  rule(top_stmt_: subtree(:st)) {
    st
  }
end

src = ARGF.read

parsed =
  begin
    Parser.new.parse(src)
  rescue Parslet::ParseFailed => failure
    $stderr.puts failure.parse_failure_cause.ascii_tree
    raise failure
  end

ast = Transform.new.apply(parsed)

puts JSON.pretty_generate(ast)
