require "json"

$fn_sigs = {}

def p_e(*args)
  args.each { |arg| $stderr.puts arg.inspect }
end

class FuncSig
  attr_reader :args, :ret

  def initialize(args, ret)
    @args = args
    @ret = ret
  end
end

class FuncContext
  attr_reader :ret_type, :type_dict

  def initialize(ret_type, type_dict)
    @ret_type = ret_type
    @type_dict = type_dict # name => type
  end
end

class TypeError < StandardError
end

def prepare_fn_sigs(top_stmts)
  top_stmts.each do |top_stmt|
    case top_stmt
    in ["func", name, ret_type, args, _]
      $fn_sigs[name] = FuncSig.new(args, ret_type)
    else
      raise "unsupported"
    end
  end

  # builtin functions
  $fn_sigs["set_vram"] = FuncSig.new(
    [["vram_addr", "int"], ["value", "int"]],
    "void"
  )
  $fn_sigs["get_vram"] = FuncSig.new(
    [["vram_addr", "int"]],
    "int"
  )
end

def assert_expr(ctx, expr, type_exp)
  type_act = check_expr(ctx, expr)

  if type_act != type_exp
    raise TypeError.new("expected (#{type_exp}) actual (#{type_act})")
  end
end

def check_expr(ctx, expr)
  case expr
  when Integer
    "int"
  when String
    if ctx.type_dict.key?(expr)
      ctx.type_dict[expr]
    else
      raise "no such variable (#{expr.inspect})"
    end
  when Array
    op, lhs, rhs = expr
    case op
    when "+", "*"
      assert_expr(ctx, lhs, "int")
      assert_expr(ctx, rhs, "int")
      "int"
    when "==", "!="
      type_l = check_expr(ctx, lhs)
      type_r = check_expr(ctx, rhs)
      if type_l != type_r
        raise TypeError
      end
      "bool"
    else
      raise "unsupported operator (#{expr.inspect})"
    end
  else
    raise "unsupported (#{expr.inspect})"
  end
end

def check_funcall(ctx, fn_name, args_act)
  args_exp = $fn_sigs[fn_name].args

  if args_act.size != args_exp.size
    raise "wrong number of arguments: expected (#{args_exp.size}) actual (#{args_act.size})"
  end

  args_exp.zip(args_act).each do |arg_exp, arg_act|
    _, type_exp = arg_exp
    assert_expr(ctx, arg_act, type_exp)
  end

  $fn_sigs[fn_name].ret
end

def check_stmt(ctx, stmt)
  case stmt
  in ["set", name, expr]
    assert_expr(ctx, expr, ctx.type_dict[name])
  in ["return", expr]
    assert_expr(ctx, expr, ctx.ret_type)
  in ["call", [fn_name, *act_args]]
    check_funcall(ctx, fn_name, act_args)
  in ["call_set", var_name, [fn_name, *act_args]]
    exp = check_funcall(ctx, fn_name, act_args)
    assert_expr(ctx, var_name, exp)
  in ["while", cond, stmts]
    assert_expr(ctx, cond, "bool")
    check_stmts(ctx, stmts)
  in ["case", *when_clauses]
    when_clauses.each do |when_clause|
      cond, *stmts = when_clause
      assert_expr(ctx, cond, "bool")
      check_stmts(ctx, stmts)
    end
  else
    # pass
  end
end

def check_stmts(ctx, stmts)
  stmts.each do |stmt|
    check_stmt(ctx, stmt)
  end
end

def check_func_def(func_def)
  _, _, ret_type, args, stmts = func_def

  ctx = FuncContext.new(ret_type, args.to_h)

  stmts.each do |stmt|
    case stmt
    in ["var", [name, type], _] then ctx.type_dict[name] = type
    in ["var", [name, type]]    then ctx.type_dict[name] = type
    else
      check_stmt(ctx, stmt)
    end
  end
end

def check(ast)
  top_stmts = ast[1..]
  prepare_fn_sigs(top_stmts)

  top_stmts.each do |top_stmt|
    case top_stmt[0]
    when "func"
      check_func_def(top_stmt)
    else
      raise
    end
  end
end

if $0 == __FILE__
  ast = JSON.parse(File.read(ARGV[0]))
  check(ast)
end
