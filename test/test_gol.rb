require_relative "./helper"
require "mrcl_vm"

class Memory
  def dump_vram_main
    rows = @vram.each_slice(5).to_a
    main = rows[0..4]

    (0..4).map { |li|
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
  TOKENS_FILE = File.join(TMP_DIR, "gol.tokens.txt")
  VGT_FILE = File.join(TMP_DIR, "gol.vgt.json")
  ASM_FILE = File.join(TMP_DIR, "gol.vga.txt")
  EXE_FILE = File.join(TMP_DIR, "gol.vge.txt")

  def setup
    setup_common()

    ENV["TEST"] = ""

    stack_size = 50
    mem = Memory.new(stack_size)
    @vm = Vm.new(mem, stack_size)
  end

  # num_generations 世代で終了するように書き換える
  def replace_gen_limit(num_generations)
    src = File.read(VG_FILE)
    open(VG_FILE_REPLACED, "w") { |f|
      f.print src.sub("var gen_limit = 0;", "var gen_limit = #{num_generations + 1};")
    }
  end

  def compile
    _system %( ruby #{PROJECT_DIR}/mrcl_lexer.rb   #{VG_FILE_REPLACED} > #{TOKENS_FILE} )
    _system %( ruby #{PROJECT_DIR}/vgparser.rb  #{TOKENS_FILE}      > #{VGT_FILE} )
    _system %( ruby #{PROJECT_DIR}/vgcodegen.rb #{VGT_FILE}         > #{ASM_FILE} )
    _system %( ruby #{PROJECT_DIR}/mrcl_asm.rb     #{ASM_FILE}         > #{EXE_FILE} )
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
