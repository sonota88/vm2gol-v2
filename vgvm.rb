# coding: utf-8
require 'pp'
require 'yaml'

class Vm
  def initialize
    # program counter
    @pc = 0

    # register
    @reg_a = 0
    @reg_b = 0
    @reg_c = 0

    # flag
    @zf = 0

    @mem = []
  end

  def load_program(path)
    @mem = YAML.load_file(path)
  end

  def start
    dump() # 初期状態

    loop do
      # operator
      op = @mem[@pc]
      case op
      when "exit"
        $stderr.puts "exit"
        exit
      when "set_reg_a"
        n = @mem[@pc + 1]
        @reg_a = n
        @pc += 2
      when "set_reg_b"
        n = @mem[@pc + 1]
        @reg_b = n
        @pc += 2
      when "set_reg_c"
        n = @mem[@pc + 1]
        @reg_c = n
        @pc += 2
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
        addr = @mem[@pc + 1]
        @pc = addr
      when "jump_eq"
        addr = @mem[@pc + 1]
        jump_eq(addr)
      else
        raise "Unknown operator (#{op})"
      end

      # 1命令実行するごとにダンプしてちょっと待つ
      dump()
      sleep 1
    end
  end

  def dump
    puts "pc(%2d) | reg_a(%d) b(%d) c(%d) | zf(%d)" % [
      @pc,
      @reg_a, @reg_b, @reg_c,
      @zf
    ]
  end

  def set_mem(addr, n)
    @mem[addr] = n
  end

  def copy_mem_to_reg_a(addr)
    @reg_a = @mem[addr]
  end

  def copy_mem_to_reg_b(addr)
    @reg_b = @mem[addr]
  end

  def copy_reg_c_to_mem(addr)
    @mem[addr] = @reg_c
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

vm = Vm.new
vm.load_program(exe_file)

vm.start
