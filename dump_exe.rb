lineno = -2

while (line = $stdin.gets)
  lineno += 1
  puts format("% 4d %s", lineno, line)
end
