file = ARGV[0]
base_dir = File.dirname(File.expand_path(file))
target_path = nil

result = ""
File.read(file).each_line do |line|
  if line =~ /^#include (.+)/
    target_path = $1
    result << line
    result << "# " + ("=" * 64) + "\n"
    result << File.read(File.join(base_dir, target_path)).chomp + "\n"
    result << "\n# " + ("=" * 64) + "\n"
    result << "#end_include #{target_path}\n"
  else
    result << line
  end
end

print result
