lineno = -2

while line = $stdin.gets do
  lineno += 1
  puts "% 4d %s" % [lineno, line]
end
