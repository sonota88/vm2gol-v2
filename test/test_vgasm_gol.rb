# coding: utf-8

require_relative "./helper"

class VgasmGolTest < Minitest::Test
  EXE_FILE = project_path("tmp/test_vgasm_gol.vge.txt")

  def setup
    setup_common()
  end

  def test_vgasm_gol
    system %( ruby #{PROJECT_DIR}/vgasm.rb #{PROJECT_DIR}/test/gol.vga.txt > #{EXE_FILE} )

    assert_equal(
      File.read(project_path("test/gol.vge.txt")),
      File.read(EXE_FILE)
    )
  end
end
