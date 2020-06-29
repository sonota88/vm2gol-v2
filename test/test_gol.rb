# coding: utf-8

require_relative "./helper"
require "vgvm"

class Memory
  def dump_vram_main
    rows = @vram.each_slice(5).to_a
    main = rows[0..4]

    (0..4).map {|li|
      format_cols(main[li])
    }.join("\n")
  end
end

class Vm
  def dump_vram_main
    @mem.dump_vram_main()
  end
end

class GolTest < Minitest::Test
  TMP_DIR = File.join(PROJECT_DIR, "tmp")

  VG_FILE = File.join(PROJECT_DIR, "gol.vg.txt")
  VG_FILE_REPLACED = File.join(TMP_DIR, "gol_replaced.vg.txt")
  VGT_FILE = File.join(TMP_DIR, "gol.vgt.json")
  ASM_FILE = File.join(TMP_DIR, "gol.vga.txt")
  EXE_FILE = File.join(TMP_DIR, "gol.vge.yaml")

  def setup
    ENV["TEST"] = ""

    stack_size = 50
    mem = Memory.new(stack_size)
    @vm = Vm.new(mem, stack_size)
  end

  # num_generations 世代で終了するように書き換える
  def replace_gen_limit(num_generations)
    src = File.read(VG_FILE)
    open(VG_FILE_REPLACED, "w") {|f|
      f.print src.sub("var gen_limit = 0;", "var gen_limit = #{num_generations + 1};")
    }
  end

  def compile
    system %( ruby #{PROJECT_DIR}/vgparser.rb #{VG_FILE_REPLACED} > #{VGT_FILE} )
    system %( ruby #{PROJECT_DIR}/vgcg.rb     #{VGT_FILE} > #{ASM_FILE} )
    system %( ruby #{PROJECT_DIR}/vgasm.rb    #{ASM_FILE} > #{EXE_FILE} )
  end

  def test_20generations
    replace_gen_limit(20)
    compile()

    @vm.load_program_file(EXE_FILE)
    @vm.start()

    assert_equal(
      [
        ".@...",
        "..@..",
        "@@@..",
        ".....",
        "....."
      ].join("\n"),
      @vm.dump_vram_main()
    )
  end

  def test_first_generation
    replace_gen_limit(1)
    compile()

    @vm.load_program_file(EXE_FILE)
    @vm.start()

    assert_equal(
      [
        ".....",
        "@.@..",
        ".@@..",
        ".@...",
        "....."
      ].join("\n"),
      @vm.dump_vram_main()
    )
  end
end
