# coding: utf-8

require_relative "./helper"

class VgasmGolTest < Minitest::Test
  EXE_FILE = File.join(PROJECT_DIR, "tmp/test_vgasm_gol.vge.yaml")

  def test_vgasm_gol
    system %( ruby #{PROJECT_DIR}/vgasm.rb #{PROJECT_DIR}/test/gol.vga.txt > #{EXE_FILE} )

    assert_equal(
      File.read("#{PROJECT_DIR}/test/gol.vge.yaml"),
      File.read(EXE_FILE)
    )
  end
end
