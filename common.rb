def p_e(*args)
  args.each{ |arg| $stderr.puts arg.inspect }
end

def pp_e(*args)
  args.each{ |arg| $stderr.puts arg.pretty_inspect }
end

def not_yet_impl(*args)
  "Not yet implemented" +
    args
    .map{ |arg| " (#{ arg.inspect })" }
    .join("")
end
