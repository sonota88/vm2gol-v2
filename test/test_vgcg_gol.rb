# coding: utf-8

require_relative "./helper"

class VgcgGolTest < Minitest::Test
  ASM_FILE = File.join(PROJECT_DIR, "tmp/test_vgasm_gol.vga.txt")

  def test_vgcg_gol
    system %( ruby #{PROJECT_DIR}/vgcg.rb #{PROJECT_DIR}/test/gol.vgt.json > #{ASM_FILE} )

    assert_equal(
      File.read("#{PROJECT_DIR}/test/gol.vga.txt"),
      File.read(ASM_FILE)
    )
  end
end
