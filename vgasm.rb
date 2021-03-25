# coding: utf-8

require "pp"
require "json"

def parse(src)
  alines = []
  src.each_line do |line|
    words = line.sub(/#.*/, "").strip.split(/ +/)
    unless words.empty?
      alines << words
    end
  end
  alines
end

def create_label_addr_map(alines)
  map = {}

  alines.each_with_index do |aline, addr|
    head, *rest = aline

    case head
    when "label"
      name = rest[0]
      map[name] = addr
    end
  end

  map
end

def to_machine_code_operand(arg)
  case arg
  when /^\[(.+)\]$/ then "ind:#{$1}"
  when /^-?\d+$/    then arg.to_i
  else                   arg
  end
end

src = File.read(ARGV[0])
alines = parse(src)

# key: ラベル名、 value: アドレス のマッピングを作る
label_addr_map = create_label_addr_map(alines)

alines.each do |aline|
  head, *rest = aline

  insn = [head]

  case head
  when "label"
    insn << rest[0]
  when "jump", "jump_eq", "call"
    label_name = rest[0]

    if label_addr_map.key?(label_name)
      insn << label_addr_map[label_name]
    else
      raise "label not found (#{label_name})"
    end
  else
    insn += rest.map {|arg| to_machine_code_operand(arg) }
  end

  puts JSON.generate(insn)
end
