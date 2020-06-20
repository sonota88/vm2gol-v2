# coding: utf-8

require "pp"
require "yaml"

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

  addr = 0
  alines.each do |aline|
    head, *rest = aline

    case head
    when "label"
      name = rest[0]
      map[name] = addr
      addr += 2
    else
      addr += 1
      addr += rest.size
    end
  end

  map
end

src = File.read(ARGV[0])
alines = parse(src)

# key: ラベル名、 value: アドレス のマッピングを作る
label_addr_map = create_label_addr_map(alines)
# pp label_addr_map

words = []
alines.each do |aline|
  head, *rest = aline

  words << head

  case head
  when "label"
    words << rest[0]
  when "jump", "jump_eq", "call"
    label_name = rest[0]
    words << label_addr_map[label_name] + 2
  else
    words += rest.map {|arg|
      (/^\-?\d+$/ =~ arg) ? arg.to_i : arg
    }
  end
end

puts YAML.dump(words)
