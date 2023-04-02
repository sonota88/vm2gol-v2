require "json"

require_relative "common"

def const?(const_names, name)
  const_names.include?(name)
end

def check_call_set(const_names, stmt)
  _, name, _ = stmt
  if const?(const_names, name)
    raise panic("Invalid assignment to const", name)
  end
end

def check_set(const_names, stmt)
  _, name, _ = stmt
  if const?(const_names, name)
    raise panic("Invalid assignment to const", name)
  end
end

def check_while(const_names, stmt)
  _, _, stmts = stmt
  check_stmts(const_names, stmts)
end

def check_case(const_names, stmt)
  _, *when_clauses = stmt
  when_clauses.each do |when_clause|
    _, *stmts = when_clause
    check_stmts(const_names, stmts)
  end
end

def check_stmt(const_names, stmt)
  case stmt[0]
  when "set"      then check_set(     const_names, stmt)
  when "call_set" then check_call_set(const_names, stmt)
  when "while"    then check_while(   const_names, stmt)
  when "case"     then check_case(    const_names, stmt)
  end
end

def check_stmts(const_names, stmts)
  stmts.each do |stmt|
    check_stmt(const_names, stmt)
  end
end

def check_func_def(func_def)
  _, fn_name, fn_arg_names, stmts = func_def
  const_names = []
  stmts.each do |stmt|
    case stmt[0]
    when "var"   then :noop
    when "const" then const_names << stmt[1]
    else
      check_stmt(const_names, stmt)
    end
  end
end

def check_top_stmts(tree)
  _, *top_stmts = tree
  top_stmts.each do |top_stmt|
    case top_stmt[0]
    when "func" then check_func_def(top_stmt)
    else
      raise panic("top_stmt", top_stmt)
    end
  end
end

def check(tree)
  check_top_stmts(tree)
end

src = File.read(ARGV[0])
tree = JSON.parse(src)
check(tree)
