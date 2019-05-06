# coding: utf-8
require 'pp'

class Vm
  def initialize
    # register
    @reg_a = 0
    @reg_b = 0
    @reg_c = 0

    @mem = [
      "set_reg_a", 1,
      "set_reg_a", 0
    ]
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
    @reg_c = @reg_a + @reg_b
  end
end

vm = Vm.new
pp vm # 初期状態

