# coding: utf-8

require_relative "./common"

def tokenize(src)
  tokens = []

  pos = 0
  lineno = 1

  while pos < src.size
    rest = src[pos .. -1]

    case rest
    when /\A( +)/
      str = $1
      pos += str.size
    when /\A(\n)/
      str = $1
      pos += str.size
      lineno += 1
    when %r{\A(#.*)$}
      str = $1
      pos += str.size
    when /\A"(.*)"/
      str = $1
      tokens << Token.new(:str, str, lineno)
      pos += str.size + 2
    when /\A(def|end|var|return|case|when|while|_cmt)[^a-z_]/
      str = $1
      tokens << Token.new(:kw, str, lineno)
      pos += str.size
    when /\A(if)[^a-z_]/
      str = $1
      tokens << Token.new(:kw, "case", lineno)
      tokens << Token.new(:kw, "when", lineno)
      pos += str.size
    when /\A(-?[0-9]+)/
      str = $1
      tokens << Token.new(:int, str.to_i, lineno)
      pos += str.size
    when /\A(==|!=|[<(){}\[\]=;+*\/%,&])/
      str = $1
      tokens << Token.new(:sym, str, lineno)
      pos += str.size
    when /\A([A-Za-z_][A-Za-z0-9_]*)/
      str = $1
      tokens << Token.new(:ident, str, lineno)
      pos += str.size
    else
      p_e rest[0...100]
      raise "must not happen (lineno=#{lineno})"
    end
  end

  tokens
end

# --------------------------------

if $PROGRAM_NAME == __FILE__
  in_file = ARGV[0]
  tokens = tokenize(File.read(in_file))

  tokens.each do |token|
    puts token.to_line()
  end
end
