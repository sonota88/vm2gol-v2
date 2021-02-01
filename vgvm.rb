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
    work_insns = []
    @main.each_with_index do |insn, i|
      work_insns << { addr: i, insn: insn }
    end

    work_insns
      .select do |work_insn|
        pc - MAIN_DUMP_WIDTH <= work_insn[:addr] &&
          work_insn[:addr] <= pc + MAIN_DUMP_WIDTH
      end
      .map do |work_insn|
        head =
          if work_insn[:addr] == pc
            "pc =>"
          else
            "     "
          end

        opcode = work_insn[:insn][0]

        color =
          case opcode
          when "exit", "call", "ret", "jump", "jump_eq"
            TermColor::RED
          when "_cmt"
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
          work_insn[:addr],
          indent,
          work_insn[:insn].inspect
        )
      end
      .join("\n")
  end

  def dump_stack(sp, bp)
    lines = []
    @stack.each_with_index do |x, i|
      addr = i
      next if addr < sp - 8
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
      lines << head + "#{addr} #{x.inspect}"
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

  def initialize(mem, stack_size)
    # program counter
    @pc = 0

    # register
    @reg_a = 0
    @reg_b = 0

    # zero flag
    @zf = FLAG_FALSE

    @mem = mem
    @sp = stack_size - 1 # stack pointer
    @bp = stack_size - 1 # base pointer

    @step = 0
  end

  def test?
    ENV.key?("TEST")
  end

  def set_sp(addr)
    raise "Stack overflow" if addr < 0

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
    when "exit"      then return true
    when "cp"        then copy()      ; @pc += 1
    when "add_ab"    then add_ab()    ; @pc += 1
    when "mult_ab"   then mult_ab()   ; @pc += 1
    when "add_sp"    then add_sp()    ; @pc += 1
    when "sub_sp"    then sub_sp()    ; @pc += 1
    when "compare"   then compare()   ; @pc += 1
    when "label"     then               @pc += 1
    when "jump"      then jump()
    when "jump_eq"   then jump_eq()
    when "call"      then call()
    when "ret"       then ret()
    when "push"      then push()      ; @pc += 1
    when "pop"       then pop()       ; @pc += 1
    when "set_vram"  then set_vram()  ; @pc += 1
    when "get_vram"  then get_vram()  ; @pc += 1
    when "_cmt"      then               @pc += 1
    else
      raise "Unknown opcode (#{opcode})"
    end

    false
  end

  def start
    unless test?
      dump() # 初期状態
      puts "Press enter key to start"
      $stdin.gets
    end

    loop do
      @step += 1

      do_exit = execute()
      return if do_exit

      unless test?
        if ENV.key?("STEP")
          dump()
          $stdin.gets
          # $stdin.gets if @step >= 600
        else
          dump() if @step % 10 == 0
        end

        # sleep 0.01
      end
    end
  end

  def dump_reg
    [
      "reg_a(#{ @reg_a.inspect })",
      "reg_b(#{ @reg_b.inspect })"
    ].join(" ")
  end

  def dump
    puts <<~DUMP
      ================================
      #{ @step }: #{ dump_reg() } zf(#{ @zf })
      ---- memory (main) ----
      #{ @mem.dump_main(@pc) }
      ---- memory (stack) ----
      #{ @mem.dump_stack(@sp, @bp) }
      ---- memory (vram) ----
      #{ @mem.dump_vram() }
    DUMP
  end

  def calc_indirect_addr(str)
    _, base_str, disp_str = str.split(":")

    base =
      case base_str
      when "bp"
        @bp
      else
        raise not_yet_impl("base_str", base_str)
      end

    base + disp_str.to_i
  end

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
      when Integer
        arg1
      when "reg_a"
        @reg_a
      when "sp"
        @sp
      when "bp"
        @bp
      when /^ind:/
        @mem.stack[calc_indirect_addr(arg1)]
      else
        raise not_yet_impl("copy src", arg1)
      end

    case arg2
    when "reg_a"
      @reg_a = src_val
    when "reg_b"
      @reg_b = src_val
    when "bp"
      @bp = src_val
    when "sp"
      set_sp(src_val)
    when /^ind:/
      @mem.stack[calc_indirect_addr(arg2)] = src_val
    else
      raise not_yet_impl("copy dest", arg2)
    end
  end

  def add_sp
    set_sp(@sp + @mem.main[@pc][1])
  end

  def sub_sp
    set_sp(@sp - @mem.main[@pc][1])
  end

  def compare
    @zf = (@reg_a == @reg_b) ? FLAG_TRUE : FLAG_FALSE
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

    val_to_push =
      case arg
      when Integer
        arg
      when String
        case arg
        when "reg_a"
          @reg_a
        when "bp"
          @bp
        when /^ind:/
          stack_addr = calc_indirect_addr(arg)
          @mem.stack[stack_addr]
        else
          raise not_yet_impl("push", arg)
        end
      else
        raise not_yet_impl("push", arg)
      end

    set_sp(@sp - 1)
    @mem.stack[@sp] = val_to_push
  end

  def pop
    arg = @mem.main[@pc][1]
    val = @mem.stack[@sp]

    case arg
    when "reg_a"
      @reg_a = val
    when "reg_b"
      @reg_b = val
    when "bp"
      @bp = val
    else
      raise not_yet_impl("pop", arg)
    end

    set_sp(@sp + 1)
  end

  def set_vram
    arg1 = @mem.main[@pc][1]
    arg2 = @mem.main[@pc][2]

    src_val =
      case arg2
      when Integer
        arg2
      when "reg_a"
        @reg_a
      when /^ind:/
        stack_addr = calc_indirect_addr(arg2)
        @mem.stack[stack_addr]
      else
        raise not_yet_impl("set_vram", arg2)
      end

    case arg1
    when Integer
      @mem.vram[arg1] = src_val
    when /^ind:/
      stack_addr = calc_indirect_addr(arg1)
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
        when /^ind:/
          stack_addr = calc_indirect_addr(arg1)
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
end

if $PROGRAM_NAME == __FILE__
  exe_file = ARGV[0]

  stack_size = 50
  mem = Memory.new(stack_size)
  vm = Vm.new(mem, stack_size)
  vm.load_program_file(exe_file)

  vm.start
  vm.dump()
  $stderr.puts "exit"
end
