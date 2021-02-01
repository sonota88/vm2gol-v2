C_MINUS = "\e[0;31m" # red
C_PLUS  = "\e[0;32m" # green
C_AT    = "\e[0;34m" # blue
C_RESET = "\e[m"

def diff(path_exp, path_act)
  out = `diff -u #{path_exp} #{path_act}`

  exit 0 if out.empty?

  out.lines.each{ |line|
    case line
    when /^ /
      print line
    when /^-/
      print C_MINUS + line + C_RESET
    when /^\+/
      print C_PLUS  + line + C_RESET
    when /^@/
      print C_AT    + line + C_RESET
    else
      print line
    end
  }

  exit 1
end

def remove_blank_line(infile, outfile)
  cmd = "cat #{infile}"
  cmd += ' | egrep -v \'^ *$\'' # Remove blank lines
  cmd += " > #{outfile}"
  system cmd
end

def filter_asm(infile, outfile)
  cmd = "cat #{infile}"
  cmd += ' | sed -e \'s/# .*$//g\'' # Remove asm comments
  cmd += ' | egrep -v \'^ *$\''     # Remove blank lines
  cmd += " > #{outfile}"
  system cmd
end

# --------------------------------

type, exp, act = ARGV

exp_tmp = "tmp/vg_exp.txt"
act_tmp = "tmp/vg_act.txt"

case type
when "text", "json"
  remove_blank_line exp, exp_tmp
  remove_blank_line act, act_tmp
when "asm"
  filter_asm exp, exp_tmp
  filter_asm act, act_tmp
else
  raise "not_yet_impl"
end

diff exp_tmp, act_tmp
