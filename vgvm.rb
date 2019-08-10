# coding: utf-8
require 'pp'
require 'yaml'

require './common'

module TermColor
  RESET  = "\e[m"
  RED    = "\e[0;31m"
end

class Memory
  attr_accessor :main, :stack, :vram

  MAIN_DUMP_WIDTH = 30

  def initialize(stack_size)
    @main = []

    # スタック領域
    @stack = Array.new(stack_size, 0)

    @vram = Array.new(50, 0)
  end

  def dump_main(pc)
    vmcmds = []
    addr = 0
    while addr < @main.size
      operator = @main[addr]
      num_args = Vm.num_args_for(operator)
      vmcmds << {
        addr: addr,
        xs: @main[addr .. addr + num_args]
      }
      addr += 1 + num_args
    end

    vmcmds
    .select {|vmcmd|
      pc - MAIN_DUMP_WIDTH <= vmcmd[:addr] &&
      vmcmd[:addr] <= pc + MAIN_DUMP_WIDTH
    }
    .map {|vmcmd|
      head =
        if vmcmd[:addr] == pc
          "pc =>"
        else
          "     "
        end

      operator = vmcmd[:xs][0]

      color =
        case operator
        when "exit", "call", "ret", "jump", "jump_eq"
          TermColor::RED
        else
          ""
        end

      indent =
        if operator == "label"
          ""
        else
          "  "
        end

      "%s %02d #{color}%s%s#{TermColor::RESET}" % [
        head,
        vmcmd[:addr],
        indent,
        vmcmd[:xs].inspect
      ]
    }.join("\n")
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
    cols.map{|col| col == 1 ? "@" : "." }.join("")
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
  def initialize(mem, stack_size)
    # program counter
    @pc = 0

    # register
    @reg_a = 0
    @reg_b = 0
    @reg_c = 0

    # flag
    @zf = 0

    @mem = mem
    # スタックポインタ
    @sp = stack_size - 1
    # ベースポインタ
    @bp = stack_size - 1

    @step = 0
  end

  def set_sp(addr)
    raise "Stack overflow" if addr < 0
    @sp = addr
  end

  def load_program(path)
    @mem.main = YAML.load_file(path)
  end

  def start
    dump_v2() # 初期状態
    $stdin.gets

    loop do
      @step += 1

      # operator
      op = @mem.main[@pc]

      pc_delta = 1 + Vm.num_args_for(op)

      case op
      when "exit"
        $stderr.puts "exit"
        exit
      when "set_reg_a"
        val = @mem.main[@pc + 1]
        set_reg_a(val)
        @pc += pc_delta
      when "set_reg_b"
        val = @mem.main[@pc + 1]
        set_reg_b(val)
        @pc += pc_delta
      when "set_reg_c"
        n = @mem.main[@pc + 1]
        @reg_c = n
        @pc += pc_delta
      when "cp"
        copy(
          @mem.main[@pc + 1],
          @mem.main[@pc + 2]
        )
        @pc += pc_delta
      when "add_ab"
        add_ab()
        @pc += pc_delta
      when "add_ac"
        add_ac()
        @pc += pc_delta
      when "mult_ab"
        mult_ab()
        @pc += pc_delta
      when "add_sp"
        set_sp(@sp + @mem.main[@pc + 1])
        @pc += pc_delta
      when "sub_sp"
        set_sp(@sp - @mem.main[@pc + 1])
        @pc += pc_delta
      when "compare"
        compare()
        @pc += pc_delta
      when "label"
        @pc += pc_delta
      when "jump"
        addr = @mem.main[@pc + 1]
        @pc = addr
      when "jump_eq"
        addr = @mem.main[@pc + 1]
        jump_eq(addr)
      when "call"
        set_sp(@sp - 1) # スタックポインタを1減らす
        @mem.stack[@sp] = @pc + 2 # 戻り先を記憶
        next_addr = @mem.main[@pc + 1] # ジャンプ先
        @pc = next_addr
      when "ret"
        ret_addr = @mem.stack[@sp] # 戻り先アドレスを取得
        @pc = ret_addr # 戻る
        set_sp(@sp + 1) # スタックポインタを戻す
      when "push"
        arg = @mem.main[@pc + 1]
        val_to_push =
          case arg
          when Integer
            arg
          when String
            case arg
            when "bp"
              @bp
            when /^\[bp\-(\d+)\]$/
              stack_addr = @bp - $1.to_i
              @mem.stack[stack_addr]
            when /^\[bp\+(\d+)\]$/
              stack_addr = @bp + $1.to_i
              @mem.stack[stack_addr]
            else
              raise not_yet_impl("push", arg)
            end
          else
            raise not_yet_impl("push", arg)
          end
        set_sp(@sp - 1)
        @mem.stack[@sp] = val_to_push
        @pc += pc_delta
      when "pop"
        arg = @mem.main[@pc + 1]
        case arg
        when "bp"
          @bp = @mem.stack[@sp]
        else
          raise not_yet_impl("pop", arg)
        end
        set_sp(@sp + 1)
        @pc += pc_delta
      when "set_vram"
        arg1 = @mem.main[@pc + 1]
        arg2 = @mem.main[@pc + 2]

        src_val =
          case arg2
          when Integer
            arg2
          when /^\[bp\+(\d+)\]$/
            stack_addr = @bp + $1.to_i
            @mem.stack[stack_addr]
          else
            raise not_yet_impl("set_vram", arg2)
          end

        case arg1
        when Integer
          @mem.vram[arg1] = src_val
        when /^\[bp-(\d+)\]$/
          stack_addr = @bp - $1.to_i
          vram_addr = @mem.stack[stack_addr]
          @mem.vram[vram_addr] = src_val
        else
          raise not_yet_impl("set_vram", arg1)
        end

        @pc += pc_delta
      when "get_vram"
        arg1 = @mem.main[@pc + 1]
        arg2 = @mem.main[@pc + 2]

        vram_addr =
          case arg1
          when Integer
            arg1
          when String
            case arg1
            when /^\[bp\-(\d+)\]$/
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

        @pc += pc_delta
      when "_cmt"
        @pc += pc_delta
      else
        raise "Unknown operator (#{op})"
      end

      dump_v2()
      $stdin.gets if @step >= 0
      sleep 0.01
    end
  end

  def copy(arg1, arg2)
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
      when /^\[bp\+(\d+)\]$/
        @mem.stack[@bp + $1.to_i]
      when /^\[bp-(\d+)\]$/
        @mem.stack[@bp - $1.to_i]
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
    when /^\[bp-(\d+)\]$/
      @mem.stack[@bp - $1.to_i] = src_val
    else
      raise not_yet_impl("copy dest", arg2)
    end
  end

  def self.num_args_for(operator)
    case operator
    when "cp", "set_vram", "get_vram"
      2
    when "set_reg_a", "set_reg_b", "label", "call", "push", "pop", "add_sp", "sub_sp", "jump_eq", "jump", "_cmt"
      1
    when "ret", "exit", "add_ab", "compare", "mult_ab"
      0
    else
      raise "Invalid operator (#{operator})"
    end
  end

  def dump_reg
    [
      "reg_a(#{ @reg_a.inspect })",
      "reg_b(#{ @reg_b.inspect })",
      "reg_c(#{ @reg_c.inspect })"
    ].join(" ")
  end

  def dump_v2
    puts <<-EOB
================================
#{ @step }: #{ dump_reg() } zf(#{ @zf })
---- memory (main) ----
#{ @mem.dump_main(@pc) }
---- memory (stack) ----
#{ @mem.dump_stack(@sp, @bp) }
---- memory (vram) ----
#{ @mem.dump_vram() }
    EOB
  end

  def set_mem(addr, n)
    @mem.main[addr] = n
  end

  def copy_mem_to_reg_a(addr)
    @reg_a = @mem.main[addr]
  end

  def copy_mem_to_reg_b(addr)
    @reg_b = @mem.main[addr]
  end

  def copy_reg_c_to_mem(addr)
    @mem.main[addr] = @reg_c
  end

  def add_ab
    @reg_a = @reg_a + @reg_b
  end

  def add_ac
    @reg_a = @reg_a + @reg_c
  end

  def mult_ab
    @reg_a = @reg_a * @reg_b
  end

  def set_reg_a(val)
    @reg_a =
      case val
      when Integer
        val
      when /^\[bp-(\d+)\]$/
        stack_addr = @bp - $1.to_i
        @mem.stack[stack_addr]
      when /^\[bp\+(\d+)\]$/
        stack_addr = @bp + $1.to_i
        @mem.stack[stack_addr]
      else
        raise not_yet_impl("val", val)
      end
  end

  def set_reg_b(val)
    @reg_b =
      case val
      when Integer
        val
      when /^\[bp-(\d+)\]$/
        stack_addr = @bp - $1.to_i
        @mem.stack[stack_addr]
      when /^\[bp\+(\d+)\]$/
        stack_addr = @bp + $1.to_i
        @mem.stack[stack_addr]
      else
        raise not_yet_impl("val", val)
      end
  end

  def compare
    @zf = (@reg_a == @reg_b) ? 1 : 0
  end

  def jump_eq(addr)
    if @zf == 1
      @pc = addr
    else
      @pc += 2
    end
  end
end

exe_file = ARGV[0]

stack_size = 50
mem = Memory.new(stack_size)
vm = Vm.new(mem, stack_size)
vm.load_program(exe_file)

vm.start
