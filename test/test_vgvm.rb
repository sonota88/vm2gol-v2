# coding: utf-8

require_relative "./helper"
require "vgvm"

class Vm
  attr_accessor :reg_a, :reg_b
  attr_accessor :pc
  attr_accessor :sp, :bp
  attr_accessor :zf
  attr_reader :mem
end

class VmTest < Minitest::Test
  def setup
    ENV["TEST"] = ""

    stack_size = 50
    mem = Memory.new(stack_size)
    @vm = Vm.new(mem, stack_size)
  end

  def execute(*words)
    @vm.load_program(words)
    @vm.execute()
  end

  # --------------------------------

  def test_set_reg_a
    execute("set_reg_a", 42)

    assert_equal(42, @vm.reg_a)
  end

  # --------------------------------

  def test_set_reg_b
    execute("set_reg_b", 42)

    assert_equal(42, @vm.reg_b)
  end

  # --------------------------------

  def test_cp_to_reg_a
    execute("cp", 42, "reg_a")

    assert_equal(42, @vm.reg_a)
  end

  def test_cp_to_reg_b
    execute("cp", 42, "reg_b")

    assert_equal(42, @vm.reg_b)
  end

  # --------------------------------

  def test_cp_from_reg_a
    @vm.reg_a = 42

    execute("cp", "reg_a", "reg_b")

    assert_equal(42, @vm.reg_b)
  end

  def test_cp_from_sp
    @vm.sp = 42

    execute("cp", "sp", "reg_a")

    assert_equal(42, @vm.reg_a)
  end

  def test_cp_from_bp
    @vm.bp = 42

    execute("cp", "bp", "reg_a")

    assert_equal(42, @vm.reg_a)
  end

  def test_cp_from_bp_plus
    @vm.bp = 45
    @vm.mem.stack[@vm.bp + 2] = 42

    execute("cp", "[bp+2]", "reg_a")

    assert_equal(42, @vm.reg_a)
  end

  def test_cp_from_bp_minus
    @vm.mem.stack[@vm.bp - 2] = 42

    execute("cp", "[bp-2]", "reg_a")

    assert_equal(42, @vm.reg_a)
  end

  # --------------------------------

  def test_cp_to_bp
    execute("cp", 42, "bp")

    assert_equal(42, @vm.bp)
  end

  def test_cp_to_sp
    execute("cp", 42, "sp")

    assert_equal(42, @vm.sp)
  end

  def test_cp_to_bp_minus
    assert_equal(49, @vm.bp)

    execute("cp", 42, "[bp-2]")

    assert_equal(42, @vm.mem.stack[49 - 2])
  end

  # --------------------------------

  def test_add_ab
    @vm.reg_a = 2
    @vm.reg_b = 3

    execute("add_ab")

    assert_equal(5, @vm.reg_a)
  end

  # --------------------------------

  def test_mult_ab
    @vm.reg_a = 2
    @vm.reg_b = 3

    execute("mult_ab")

    assert_equal(6, @vm.reg_a)
  end

  # --------------------------------

  def test_add_sb
    @vm.sp = 45

    execute("add_sp", 2)

    assert_equal(45 + 2, @vm.sp)
  end

  # --------------------------------

  def test_sub_sp
    assert_equal(49, @vm.sp)

    execute("sub_sp", 2)

    assert_equal(49 - 2, @vm.sp)
  end

  # --------------------------------

  def test_compare_equal
    @vm.reg_a = 0
    @vm.reg_b = 0

    execute("compare")

    assert_equal(Vm::FLAG_TRUE, @vm.zf)
  end

  def test_compare_not_equal
    @vm.reg_a = 0
    @vm.reg_b = 1

    execute("compare")

    assert_equal(Vm::FLAG_FALSE, @vm.zf)
  end

  # --------------------------------

  def test_jump
    execute("jump", 3)

    assert_equal(3, @vm.pc)
  end

  # --------------------------------

  def test_jump_eq_equal
    @vm.zf = Vm::FLAG_TRUE
    @vm.reg_b = 1

    execute("jump_eq", 3)

    assert_equal(3, @vm.pc)
  end

  def test_jump_eq_not_equal
    @vm.zf = Vm::FLAG_FALSE
    @vm.reg_b = 1

    execute("jump_eq", 3)

    assert_equal(2, @vm.pc)
  end

  # --------------------------------

  def test_call
    assert_equal(0, @vm.pc)
    assert_equal(49, @vm.sp)

    execute("call", 8)

    assert_equal(49 - 1, @vm.sp)
    assert_equal(0 + 2, @vm.mem.stack[@vm.sp])
    assert_equal(8, @vm.pc)
  end

  # --------------------------------

  def test_ret
    @vm.sp = 45
    @vm.mem.stack[@vm.sp] = 0
    @vm.pc = 1

    execute(nil, "ret")

    assert_equal(45 + 1, @vm.sp)
    assert_equal(0, @vm.pc)
  end

  # --------------------------------

  def test_push_imm
    @vm.sp = 48

    execute("push", 42)

    assert_equal(48 - 1, @vm.sp)
    assert_equal(42, @vm.mem.stack[@vm.sp])
  end

  def test_push_reg_a
    @vm.reg_a = 42
    @vm.sp = 48

    execute("push", "reg_a")

    assert_equal(48 - 1, @vm.sp)
    assert_equal(42, @vm.reg_a)
  end

  def test_push_bp
    @vm.sp = 48
    assert_equal(49, @vm.bp)

    execute("push", "bp")

    assert_equal(48 - 1, @vm.sp)
    assert_equal(49, @vm.mem.stack[@vm.sp])
  end

  def test_push_bp_minus
    assert_equal(49, @vm.sp)
    assert_equal(49, @vm.bp)
    @vm.mem.stack[49 - 2] = 42

    execute("push", "[bp-2]")

    assert_equal(49 - 1, @vm.sp)
    assert_equal(42, @vm.mem.stack[@vm.sp])
  end

  def test_push_bp_plus
    @vm.sp = 45
    @vm.bp = 45
    @vm.mem.stack[45 + 2] = 42

    execute("push", "[bp+2]")

    assert_equal(45 - 1, @vm.sp)
    assert_equal(42, @vm.mem.stack[@vm.sp])
  end

  # --------------------------------

  def test_pop_reg_a
    @vm.sp = 45
    @vm.mem.stack[@vm.sp] = 42

    execute("pop", "reg_a")

    assert_equal(45 + 1, @vm.sp)
    assert_equal(42, @vm.reg_a)
  end

  def test_pop_reg_b
    @vm.sp = 45
    @vm.mem.stack[@vm.sp] = 42

    execute("pop", "reg_b")

    assert_equal(45 + 1, @vm.sp)
    assert_equal(42, @vm.reg_b)
  end

  def test_pop_bp
    @vm.sp = 45
    @vm.mem.stack[@vm.sp] = 42

    execute("pop", "bp")

    assert_equal(45 + 1, @vm.sp)
    assert_equal(42, @vm.bp)
  end

  # --------------------------------

  def test_set_vram_bp_plus
    @vm.bp = 45
    @vm.mem.stack[@vm.bp + 2] = 1

    assert_equal(0, @vm.mem.vram[0])

    execute("set_vram", 0, "[bp+2]")

    assert_equal(1, @vm.mem.vram[0])
  end

  def test_set_vram_bp_minus
    @vm.bp = 45
    @vm.mem.stack[@vm.bp - 2] = 1

    assert_equal(0, @vm.mem.vram[0])

    execute("set_vram", 0, "[bp-2]")

    assert_equal(1, @vm.mem.vram[0])
  end

  def test_set_vram_set_to_bp_minus
    @vm.bp = 45
    @vm.mem.stack[@vm.bp - 2] = 0

    assert_equal(0, @vm.mem.vram[0])

    execute("set_vram", "[bp-2]", 1)

    assert_equal(1, @vm.mem.vram[0])
  end

  # --------------------------------

  def test_get_vram_imm
    @vm.mem.vram[0] = 1

    execute("get_vram", 0, "reg_a")

    assert_equal(1, @vm.reg_a)
  end

  def test_get_vram_bp_minus
    @vm.mem.vram[0] = 1
    @vm.mem.stack[@vm.bp - 2] = 0

    execute("get_vram", "[bp-2]", "reg_a")

    assert_equal(1, @vm.reg_a)
  end
end
