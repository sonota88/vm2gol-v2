# coding: utf-8

require_relative "./common"

def tokenize(src)
  tokens = []

  pos = 0

  while pos < src.size
    rest = src[pos .. -1]

    case rest
    when /\A([ \n]+)/
      str = $1
      pos += str.size
    when %r{\A(//.*)$}
      str = $1
      pos += str.size
    when /\A"(.*)"/
      str = $1
      tokens << Token.new(:str, str)
      pos += str.size + 2
    when /\A(func|set|var|call_set|call|return|case|while|_cmt)[^a-z_]/
      str = $1
      tokens << Token.new(:kw, str)
      pos += str.size
    when /\A(-?[0-9]+)/
      str = $1
      tokens << Token.new(:int, str.to_i)
      pos += str.size
    when /\A(==|!=|[(){}=;+*,])/
      str = $1
      tokens << Token.new(:sym, str)
      pos += str.size
    when /\A([a-z_][a-z0-9_\[\]]*)/
      str = $1
      tokens << Token.new(:ident, str)
      pos += str.size
    else
      p_e rest[0...100]
      raise "must not happen"
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
