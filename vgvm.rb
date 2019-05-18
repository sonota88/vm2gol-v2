# coding: utf-8
require 'pp'
require 'yaml'

class Memory
  attr_accessor :main

  def initialize
    @main = []
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
    # スタック領域
    @stack = Array.new(4, 0)
    # スタックポインタ
    @sp = 3
  end

  def load_program(path)
    @mem.main = YAML.load_file(path)
  end

  def start
    dump() # 初期状態
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
        @stack[@sp] = @pc + 2 # 戻り先を記憶
        next_addr = @mem.main[@pc + 1] # ジャンプ先
        @pc = next_addr
      when "ret"
        ret_addr = @stack[@sp] # 戻り先アドレスを取得
        @pc = ret_addr # 戻る
        @sp += 1 # スタックポインタを戻す
      else
        raise "Unknown operator (#{op})"
      end

      dump()
      $stdin.gets
    end
  end

  def dump
    print "%- 10s | pc(%2d) | reg_a(%d) b(%d) c(%d) | zf(%d) | sp(%d,%d)" % [
      @mem.main[@pc],
      @pc,
      @reg_a, @reg_b, @reg_c,
      @zf,
      @sp, @stack[@sp]
    ]
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

mem = Memory.new
vm = Vm.new(mem)
vm.load_program(exe_file)

vm.start
