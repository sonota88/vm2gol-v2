# coding: utf-8
require "minitest/autorun"
require_relative "../vgvm"

class GolTest < Minitest::Test
  PROJECT_DIR = File.join(__dir__, "../")
  TMP_DIR = File.join(PROJECT_DIR, "tmp")

  VG_FILE = File.join(PROJECT_DIR, "gol.vg.txt")
  VGT_FILE = File.join(TMP_DIR, "gol.vgt.json")
  ASM_FILE = File.join(TMP_DIR, "gol.vga.txt")
  EXE_FILE = File.join(TMP_DIR, "gol.vge.yaml")

  def setup
    ENV["TEST"] = ""

    stack_size = 50
    mem = Memory.new(stack_size)
    @vm = Vm.new(mem, stack_size)
  end

  def test_20generations
    system %Q{ ruby #{PROJECT_DIR}/vgparser.rb #{VG_FILE}  > #{VGT_FILE} }
    system %Q{ ruby #{PROJECT_DIR}/vgcg.rb     #{VGT_FILE} > #{ASM_FILE} }
    system %Q{ ruby #{PROJECT_DIR}/vgasm.rb    #{ASM_FILE} > #{EXE_FILE} }

    @vm.load_program(EXE_FILE)
    @vm.start()

    assert_equal(
      [
        ".@...",
        "..@..",
        "@@@..",
        ".....",
        ".....",
      ].join("\n"),
      @vm.dump_vram_main()
    )
  end
end
