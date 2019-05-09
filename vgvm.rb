# coding: utf-8
require 'pp'

class Vm
  def initialize
    # program counter
    @pc = 0

    # register
    @reg_a = 0
    @reg_b = 0
    @reg_c = 0

    @mem = [
      # 0
      "set_reg_a", 1,
      # 2
      "set_reg_b", 1,
      # 4
      "add_ab",
      # 5
      "jump", 4
    ]
  end

  def start
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
      when "add_ab"
        add_ab()
        @pc += 1
      when "jump"
        addr = @mem[@pc + 1]
        @pc = addr
      else
        raise "Unknown operator (#{op})"
      end

      # 1命令実行するごとにダンプしてちょっと待つ
      pp self
      sleep 1
    end
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
end

vm = Vm.new
pp vm # 初期状態

vm.start
