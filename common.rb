require "pp"

class Token
  attr_reader :kind, :value

  # kind:
  #   str:   string
  #   kw:    keyword
  #   int:   integer
  #   sym:   symbol
  #   ident: identifier
  def initialize(kind, value)
    @kind = kind
    @value = value
  end

  def to_line
    "#{@kind}:#{@value}"
  end

  def get_value
    case @kind
    when :int   then @value.to_i
    when :ident then @value
    else
      raise "invalid kind"
    end
  end

  def self.from_line(line)
    if /^(.+?):(.+)$/ =~ line
      Token.new($1.to_sym, $2)
    else
      nil
    end
  end
end

def p_e(*args)
  args.each {|arg| $stderr.puts arg.inspect }
end

def pp_e(*args)
  args.each {|arg| $stderr.puts arg.pretty_inspect }
end

def not_yet_impl(*args)
  "Not yet implemented" +
    args
    .map {|arg| " (#{ arg.inspect })" }
    .join("")
end
