require "json"

require_relative "common"

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
          when "exit", "call", "ret", "jmp", "je"
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
    cols.map { |col| col == 1 ? "@" : "." }.join("")
  end

  def dump_vram
    rows = @vram.each_slice(5).to_a
    main = rows[0..4]
    buf = rows[5..9]

    (0..4)
      .map do |li| # line index
        format_cols(main[li]) + " " + format_cols(buf[li])
      end
      .join("\n")
  end
end

class Vm
  FLAG_TRUE = 1
  FLAG_FALSE = 0

  def initialize(mem, stack_size)
    @pc = 0 # program counter

    # registers
    @reg_a = 0
    @reg_b = 0

    @zf = FLAG_FALSE # zero flag

    @mem = mem
    @sp = stack_size - 1 # stack pointer
    @bp = stack_size - 1 # base pointer

    @step = 0
    @debug = false
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
    when "exit"     then return true
    when "mov"      then insn_mov()      ; @pc += 1
    when "add"      then insn_add()      ; @pc += 1
    when "mul"      then insn_mul()      ; @pc += 1
    when "cmp"      then insn_cmp()      ; @pc += 1
    when "label"    then                   @pc += 1
    when "jmp"      then insn_jmp()
    when "je"       then insn_je()
    when "call"     then insn_call()
    when "ret"      then insn_ret()
    when "push"     then insn_push()     ; @pc += 1
    when "pop"      then insn_pop()      ; @pc += 1
    when "set_vram" then insn_set_vram() ; @pc += 1
    when "get_vram" then insn_get_vram() ; @pc += 1
    when "_cmt"     then                   @pc += 1
    when "_debug"   then insn__debug()   ; @pc += 1
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
        if ENV.key?("STEP") || @debug
          dump()
          $stdin.gets
        else
          dump() if @step % 10 == 0
        end
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
        raise panic("base_str", base_str)
      end

    base + disp_str.to_i
  end

  def insn_add
    arg_dest = @mem.main[@pc][1]
    arg_src  = @mem.main[@pc][2]

    src_val =
      case arg_src
      when String
        if arg_src == "reg_b"
          @reg_b
        else
          raise panic("unsupported", arg_src)
        end
      when Integer
        arg_src
      else
        raise panic("unsupported", arg_src)
      end

    case arg_dest
    when "reg_a"
      @reg_a += src_val
    when "sp"
      set_sp(@sp + src_val)
    else
      raise panic("unsupported", arg_dest)
    end
  end

  def insn_mul
    arg_src  = @mem.main[@pc][1]

    src_val =
      if arg_src == "reg_b"
        @reg_b
      else
        raise panic("unsupported", arg_src)
      end

    @reg_a = @reg_a * src_val
  end

  def insn_mov
    arg_dest = @mem.main[@pc][1]
    arg_src  = @mem.main[@pc][2]

    src_val =
      case arg_src
      when Integer
        arg_src
      when "reg_a"
        @reg_a
      when "sp"
        @sp
      when "bp"
        @bp
      when /^mem:/
        @mem.stack[calc_indirect_addr(arg_src)]
      else
        raise panic("copy src", arg_src)
      end

    case arg_dest
    when "reg_a"
      @reg_a = src_val
    when "reg_b"
      @reg_b = src_val
    when "bp"
      @bp = src_val
    when "sp"
      set_sp(src_val)
    when /^mem:/
      @mem.stack[calc_indirect_addr(arg_dest)] = src_val
    else
      raise panic("copy dest", arg_dest)
    end
  end

  def insn_cmp
    @zf = (@reg_a == @reg_b) ? FLAG_TRUE : FLAG_FALSE
  end

  def insn_jmp
    jump_dest = @mem.main[@pc][1]
    @pc = jump_dest
  end

  def insn_je
    if @zf == FLAG_TRUE
      jump_dest = @mem.main[@pc][1]
      @pc = jump_dest
    else
      @pc += 1
    end
  end

  def insn_call
    set_sp(@sp - 1) # スタックポインタを1減らす
    @mem.stack[@sp] = @pc + 1 # 戻り先を記憶
    next_addr = @mem.main[@pc][1] # ジャンプ先
    @pc = next_addr
  end

  def insn_ret
    ret_addr = @mem.stack[@sp] # 戻り先アドレスを取得
    @pc = ret_addr # 戻る
    set_sp(@sp + 1) # スタックポインタを戻す
  end

  def insn_push
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
        when /^mem:/
          stack_addr = calc_indirect_addr(arg)
          @mem.stack[stack_addr]
        else
          raise panic("push", arg)
        end
      else
        raise panic("push", arg)
      end

    set_sp(@sp - 1)
    @mem.stack[@sp] = val_to_push
  end

  def insn_pop
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
      raise panic("pop", arg)
    end

    set_sp(@sp + 1)
  end

  def insn_set_vram
    arg_vram = @mem.main[@pc][1]
    arg_val = @mem.main[@pc][2]

    src_val =
      case arg_val
      when Integer
        arg_val
      when "reg_a"
        @reg_a
      when /^mem:/
        stack_addr = calc_indirect_addr(arg_val)
        @mem.stack[stack_addr]
      else
        raise panic("arg_val", arg_val)
      end

    case arg_vram
    when Integer
      @mem.vram[arg_vram] = src_val
    when /^mem:/
      stack_addr = calc_indirect_addr(arg_vram)
      vram_addr = @mem.stack[stack_addr]
      @mem.vram[vram_addr] = src_val
    else
      raise panic("arg_vram", arg_vram)
    end
  end

  def insn_get_vram
    arg_vram = @mem.main[@pc][1]
    arg_dest = @mem.main[@pc][2]

    vram_addr =
      case arg_vram
      when Integer
        arg_vram
      when String
        case arg_vram
        when /^mem:/
          stack_addr = calc_indirect_addr(arg_vram)
          @mem.stack[stack_addr]
        else
          raise panic("arg_vram", arg_vram)
        end
      else
        raise panic("arg_vram", arg_vram)
      end

    val = @mem.vram[vram_addr]

    case arg_dest
    when "reg_a"
      @reg_a = val
    else
      raise panic("arg_dest", arg_dest)
    end
  end

  def insn__debug
    @debug = true
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
