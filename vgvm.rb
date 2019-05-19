# coding: utf-8
require 'pp'
require 'yaml'

module TermColor
  RESET  = "\e[m"
  RED    = "\e[0;31m"
end

class Memory
  attr_accessor :main, :stack

  def initialize(stack_size)
    @main = []

    # スタック領域
    @stack = Array.new(stack_size, 0)
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

    vmcmds.map{ |vmcmd|
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
end

class Vm
  def initialize(mem)
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
    @sp = 3
    # ベースポインタ
    @bp = 3
  end

  def load_program(path)
    @mem.main = YAML.load_file(path)
  end

  def start
    dump_v2() # 初期状態
    $stdin.gets

    loop do
      # operator
      op = @mem.main[@pc]
      case op
      when "exit"
        $stderr.puts "exit"
        exit
      when "set_reg_a"
        n = @mem.main[@pc + 1]
        @reg_a = n
        @pc += 2
      when "set_reg_b"
        n = @mem.main[@pc + 1]
        @reg_b = n
        @pc += 2
      when "set_reg_c"
        n = @mem.main[@pc + 1]
        @reg_c = n
        @pc += 2
      when "copy_bp_to_sp"
        @sp = @bp
        @pc += 1
      when "add_ab"
        add_ab()
        @pc += 1
      when "add_ac"
        add_ac()
        @pc += 1
      when "compare"
        compare()
        @pc += 1
      when "label"
        @pc += 2
      when "jump"
        addr = @mem.main[@pc + 1]
        @pc = addr
      when "jump_eq"
        addr = @mem.main[@pc + 1]
        jump_eq(addr)
      when "call"
        @sp -= 1 # スタックポインタを1減らす
        @mem.stack[@sp] = @pc + 2 # 戻り先を記憶
        next_addr = @mem.main[@pc + 1] # ジャンプ先
        @pc = next_addr
      when "ret"
        ret_addr = @mem.stack[@sp] # 戻り先アドレスを取得
        @pc = ret_addr # 戻る
        @sp += 1 # スタックポインタを戻す
      else
        raise "Unknown operator (#{op})"
      end

      dump_v2()
      $stdin.gets
    end
  end

  def self.num_args_for(operator)
    case operator
    when "set_reg_a", "label", "call"
      1
    when "ret", "exit", "copy_bp_to_sp"
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
#{ dump_reg() } zf(#{ @zf })
---- memory (main) ----
#{ @mem.dump_main(@pc) }
---- memory (stack) ----
#{ @mem.dump_stack(@sp, @bp) }
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

mem = Memory.new(4)
vm = Vm.new(mem)
vm.load_program(exe_file)

vm.start
