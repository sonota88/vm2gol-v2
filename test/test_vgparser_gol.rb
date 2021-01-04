# coding: utf-8

require_relative "./helper"

class VgparserGolTest < Minitest::Test
  TREE_FILE = project_path("tmp/test_vgasm_gol.vgt.json")

  def setup
    setup_common()
  end

  def test_vgcg_gol
    system %( ruby #{PROJECT_DIR}/vgparser.rb #{PROJECT_DIR}/gol.vg.txt > #{TREE_FILE} )

    assert_equal(
      File.read(project_path("test/gol.vgt.json")),
      File.read(TREE_FILE)
    )
  end
end
