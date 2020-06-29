# coding: utf-8

require_relative "./helper"

class VgparserGolTest < Minitest::Test
  TREE_FILE = File.join(PROJECT_DIR, "tmp/test_vgasm_gol.vgt.json")

  def test_vgcg_gol
    system %( ruby #{PROJECT_DIR}/vgparser.rb #{PROJECT_DIR}/gol.vg.txt > #{TREE_FILE} )

    assert_equal(
      File.read("#{PROJECT_DIR}/test/gol.vgt.json"),
      File.read(TREE_FILE)
    )
  end
end
