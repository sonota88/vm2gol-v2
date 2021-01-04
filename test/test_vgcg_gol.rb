# coding: utf-8

require_relative "./helper"

class VgcgGolTest < Minitest::Test
  ASM_FILE = project_path("tmp/test_vgasm_gol.vga.txt")

  def setup
    setup_common()
  end

  def test_vgcg_gol
    system %( ruby #{PROJECT_DIR}/vgcg.rb #{PROJECT_DIR}/test/gol.vgt.json > #{ASM_FILE} )

    assert_equal(
      File.read(project_path("test/gol.vga.txt")),
      File.read(ASM_FILE)
    )
  end
end
