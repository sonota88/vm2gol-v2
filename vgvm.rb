# coding: utf-8

require "pp"
require "json"

require_relative "./common"

module TermColor
  RESET  = "\e[m"
  RED    = "\e[0;31m"
  BLUE   = "\e[0;34m"
end

class Memory
  attr_accessor :main, :stack, :vram

  MAIN_DUMP_WIDTH = 10

  def initialize(stack_size)
    @main = []

    # スタック領域
    @stack = Array.new(stack_size, 0)

    @vram = Array.new(50, 0)
  end

  def dump_main(pc)
    vmcmds = []
    @main.each_with_index do |insn, i|
      vmcmds << { addr: i, insn: insn }
    end

    vmcmds
      .select do |vmcmd|
        pc - MAIN_DUMP_WIDTH <= vmcmd[:addr] &&
          vmcmd[:addr] <= pc + MAIN_DUMP_WIDTH
      end
      .map do |vmcmd|
        head =
          if vmcmd[:addr] == pc
            "pc =>"
          else
            "     "
          end

        opcode = vmcmd[:insn][0]

        color =
          case opcode
          when "exit", "call", "ret", "jump", "jump_eq", "jump_g"
            TermColor::RED
          when "_cmt", "_debug"
            TermColor::BLUE
          else
            ""
          end

        indent =
          if opcode == "label"
            ""
          else
            "  "
          end

        format(
          "%s %02d #{color}%s%s#{TermColor::RESET}",
          head,
          vmcmd[:addr],
          indent,
          vmcmd[:insn].inspect
        )
      end
      .join("\n")
  end

  def _chr(n)
    if n.nil?
      return "! nil"
    end
    unless n.is_a?(Integer)
      return "! non-integer"
    end

    if n < 32
      if n == 12
        "LF"
      else
        "ctrl"
      end
    elsif 32 <= n && n < 128
      "'#{n.chr}'"
    else
      ""
    end
  end

  def dump_stack(sp, bp)
    lines = []
    @stack.each_with_index do |x, i|
      addr = i
      next if addr < sp - 12
      next if addr > sp + 8

      head =
        case addr
        when sp
          if sp == bp
            "sp bp => "
          else
            "sp    => "
          end
        when bp
          "   bp => "
        else
          "         "
        end
      begin
        lines << head + format("%04d % 4d %s", addr, x, _chr(x))
      rescue => e
        lines << [e.message, { x: x }].inspect
      end
    end
    lines.join("\n")
  end

  def format_cols(cols)
    cols.map {|col| col == 1 ? "@" : "." }.join("")
  end

  def dump_vram
    rows = @vram.each_slice(5).to_a
    main = rows[0..4]
    buf = rows[5..9]

    (0..4).map {|li| # line index
      format_cols(main[li]) + " " + format_cols(buf[li])
    }.join("\n")
  end
end

class Vm
  FLAG_TRUE = 1
  FLAG_FALSE = 0

  def initialize(mem, stack_size, debug, verbose)
    @debug = debug

    @verbose =
      if @debug
        true
      else
        verbose
      end

    # program counter
    @pc = 0

    # register
    @reg_a = 0
    @reg_b = 0

    @zf = FLAG_FALSE # zero flag
    @sf = FLAG_FALSE # sign flag

    @mem = mem
    @sp = stack_size - 1 # stack pointer
    @bp = stack_size - 1 # base pointer

    @step = 0

    @output = ""
  end

  def set_sp(addr)
    if addr < 0
      dump_at_exit()
      raise "Stack overflow"
    end

    @sp = addr
  end

  def load_program_file(path)
    insns = File.open(path).each_line.map { |line| JSON.parse(line) }
    load_program(insns)
  end

  def load_program(insns)
    @mem.main = insns
  end

  def execute
    insn = @mem.main[@pc]

    opcode = insn[0]

    case opcode
    when "exit"     then return true
    when "cp"       then copy()     ; @pc += 1
    when "lea"      then lea()      ; @pc += 1
    when "add_ab"   then add_ab()   ; @pc += 1
    when "mult_ab"  then mult_ab()  ; @pc += 1
    when "add_sp"   then add_sp()   ; @pc += 1
    when "sub_sp"   then sub_sp()   ; @pc += 1
    when "compare"  then compare()  ; @pc += 1
    when "label"    then              @pc += 1
    when "jump"     then jump()
    when "jump_eq"  then jump_eq()
    when "jump_g"   then jump_g()
    when "call"     then call()
    when "ret"      then ret()
    when "push"     then push()     ; @pc += 1
    when "pop"      then pop()      ; @pc += 1
    when "getchar"  then getchar()  ; @pc += 1
    when "putchar"  then putchar()  ; @pc += 1
    when "set_vram" then set_vram() ; @pc += 1
    when "get_vram" then get_vram() ; @pc += 1
    when "_cmt"     then              @pc += 1
    when "_debug"   then _debug()   ; @pc += 1
    else
      raise "Unknown opcode (#{opcode})"
    end

    false
  end

  def start
    dump() # 初期状態
    if @debug
      $stderr.puts "Press enter key to start"
      $stdin.gets
    end

    loop do
      @step += 1

      do_exit = execute()
      if do_exit
        dump()
        $stderr.puts "exit" if @verbose
        return
      end

      dump()
      $stdin.gets if @debug
    end
  end

  def dump_reg
    [
      "reg_a(#{ @reg_a.inspect })",
      "reg_b(#{ @reg_b.inspect })"
    ].join(" ")
  end

  def dump
    return unless @verbose

    $stderr.puts <<~DUMP
      ================================
      #{ @step }: #{ dump_reg() } zf(#{ @zf }) sf(#{ @sf })
      ---- memory (main) ----
      #{ @mem.dump_main(@pc) }
      ---- memory (stack) ----
      #{ @mem.dump_stack(@sp, @bp) }
      ---- memory (vram) ----
      #{ @mem.dump_vram() }
      ---- output ----
      #{ @output.inspect }
    DUMP
  end

  def get_value(str)
    case str
    when "reg_a"   then @reg_a
    when "reg_b"   then @reg_b
    when "bp"      then @bp
    when "sp"      then @sp
    when /^-?\d+$/ then str.to_i
    when /^ind:/   then @mem.stack[calc_indirect_addr(str)]
    else
      raise not_yet_impl("str", str)
    end
  end

  def calc_indirect_addr(str)
    _, base_str, disp_str, index_str = str.split(":")
    
    base  = get_value(base_str)
    disp  = get_value(disp_str)
    index = get_value(index_str)

    base + disp + index
  end

  def dump_at_exit
    lines = []
    @mem.stack.each_with_index do |n, i|
      line = format("%04d (% 4d) (0x% 4x)", i, n, n)
      if 32 <= n && n <= 126
        line += " (#{ n.chr })"
      end
      lines << line
    end

    File.open("tmp/dump.txt", "wb") { |f|
      f.puts lines.join("\n")
    }
  end

  # --------------------------------

  def add_ab
    @reg_a = @reg_a + @reg_b
  end

  def mult_ab
    @reg_a = @reg_a * @reg_b
  end

  def copy
    arg1 = @mem.main[@pc][1]
    arg2 = @mem.main[@pc][2]

    src_val =
      case arg1
      when Integer then arg1
      when String  then get_value(arg1)
      else
        raise not_yet_impl("copy src", arg1)
      end

    case arg2
    when "reg_a"          then @reg_a                               = src_val
    when "reg_b"          then @reg_b                               = src_val
    when "bp"             then @bp                                  = src_val
    when "sp"             then set_sp(src_val)
    when /^ind:/          then @mem.stack[calc_indirect_addr(arg2)] = src_val
    else
      raise not_yet_impl("copy dest", arg2)
    end
  end

  # load effective address
  def lea
    _, dest, src = @mem.main[@pc]

    addr =
      case src
      when /^ind:/
        calc_indirect_addr(src)
      else
        raise not_yet_impl("src", src)
      end

    case dest
    when "reg_a"
      @reg_a = addr
    else
      raise not_yet_impl("dest", dest)
    end
  end

  def add_sp
    set_sp(@sp + @mem.main[@pc][1])
  end

  def sub_sp
    set_sp(@sp - @mem.main[@pc][1])
  end

  def compare
    result = @reg_b - @reg_a
    @zf = (result == 0) ? FLAG_TRUE : FLAG_FALSE
    @sf = (0 <= result) ? FLAG_TRUE : FLAG_FALSE
  end

  def jump
    jump_dest = @mem.main[@pc][1]
    @pc = jump_dest
  end

  def jump_eq
    if @zf == FLAG_TRUE
      jump_dest = @mem.main[@pc][1]
      @pc = jump_dest
    else
      @pc += 1
    end
  end

  def jump_g
    if @zf == FLAG_FALSE && @sf == FLAG_TRUE
      jump_dest = @mem.main[@pc][1]
      @pc = jump_dest
    else
      @pc += 1
    end
  end

  def call
    set_sp(@sp - 1) # スタックポインタを1減らす
    @mem.stack[@sp] = @pc + 1 # 戻り先を記憶
    next_addr = @mem.main[@pc][1] # ジャンプ先
    @pc = next_addr
  end

  def ret
    ret_addr = @mem.stack[@sp] # 戻り先アドレスを取得
    @pc = ret_addr # 戻る
    set_sp(@sp + 1) # スタックポインタを戻す
  end

  def push
    arg = @mem.main[@pc][1]

    val_to_push = get_value(arg)

    set_sp(@sp - 1)
    @mem.stack[@sp] = val_to_push
  end

  def pop
    arg = @mem.main[@pc][1]
    val = @mem.stack[@sp]

    case arg
    when "reg_a" then @reg_a = val
    when "reg_b" then @reg_b = val
    when "bp"    then @bp    = val
    else
      raise not_yet_impl("pop", arg)
    end

    set_sp(@sp + 1)
  end

  def getchar
    raise "stdin is not available" if $stdin_.nil?

    arg = @mem.main[@pc][1]

    c = $stdin_.getc
    n =
      if c.nil?
        -1 # EOF
      else
        c.ord
      end

    case arg
    when "reg_a"
      @reg_a = n
    else
      raise not_yet_impl("arg", arg)
    end
  end

  def putchar
    arg = @mem.main[@pc][1]

    n =
      case arg
      when Integer
        arg
      when "reg_a"
        @reg_a
      else
        raise not_yet_impl("arg", arg)
      end

    c = n.chr
    $stdout.write c

    @output += c
    if 80 < @output.size
      @output = @output[1..-1]
    end
  end

  def set_vram
    arg1 = @mem.main[@pc][1]
    arg2 = @mem.main[@pc][2]

    src_val =
      case arg2
      when Integer
        arg2
      when /^\[bp\+(\d+)\]$/
        raise "TODO [...] 記法をやめる"
        stack_addr = @bp + $1.to_i
        @mem.stack[stack_addr]
      when /^\[bp-(\d+)\]$/
        raise "TODO [...] 記法をやめる"
        stack_addr = @bp - $1.to_i
        @mem.stack[stack_addr]
      else
        raise not_yet_impl("set_vram", arg2)
      end

    case arg1
    when Integer
      @mem.vram[arg1] = src_val
    when /^\[bp-(\d+)\]$/
      raise "TODO [...] 記法をやめる"
      stack_addr = @bp - $1.to_i
      vram_addr = @mem.stack[stack_addr]
      @mem.vram[vram_addr] = src_val
    else
      raise not_yet_impl("set_vram", arg1)
    end
  end

  def get_vram
    arg1 = @mem.main[@pc][1]
    arg2 = @mem.main[@pc][2]

    vram_addr =
      case arg1
      when Integer
        arg1
      when String
        case arg1
        when /^\[bp-(\d+)\]$/
          raise "TODO [...] 記法をやめる"
          stack_addr = @bp - $1.to_i
          @mem.stack[stack_addr]
        else
          raise not_yet_impl("arg1", arg1)
        end
      else
        raise not_yet_impl("arg1", arg1)
      end

    val = @mem.vram[vram_addr]

    case arg2
    when "reg_a"
      @reg_a = val
    else
      raise not_yet_impl("arg2", arg2)
    end
  end

  def _debug
    @debug = true
  end
end

def env_to_bool(key, default = false)
  if ENV.key?(key)
    case ENV[key]
    when "0" then false
    when "1" then true
    else          default
    end
  else
    false
  end
end

$stdin_ = nil

if $PROGRAM_NAME == __FILE__
  stdin_file = "tmp/stdin"
  # File.open(stdin_file, "wb"){|f| f.write $stdin.read }

  exe_file = ARGV[0]

  ARGV.each { |arg|
    if /^stdin=(.+)/ =~ arg
      stdin_file = $1
    end
  }
  if File.exist?(stdin_file)
    $stdin_ = File.open(stdin_file, "rb")
  end

  stack_size = 600
  mem = Memory.new(stack_size)
  vm = Vm.new(
    mem,
    stack_size,
    env_to_bool("DEBUG"),
    env_to_bool("VERBOSE")
  )
  vm.load_program_file(exe_file)
  vm.start
end
