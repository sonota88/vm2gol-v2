class Token
  attr_reader :type, :value

  # type:
  #   str:   string
  #   kw:    keyword
  #   int:   integer
  #   sym:   symbol
  #   ident: identifier
  def initialize(type, value)
    @type = type
    @value = value
  end

  def to_line
    "#{@type}:#{@value}"
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
