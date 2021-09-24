require_relative "./helper"

class VgparserGolTest < Minitest::Test
  TOKENS_FILE = project_path("tmp/test_vgasm_gol.tokens.txt")
  TREE_FILE = project_path("tmp/test_vgasm_gol.vgt.json")

  def setup
    setup_common()
  end

  def test_gol
    system %( ruby #{PROJECT_DIR}/vglexer.rb  #{PROJECT_DIR}/gol.vg.txt > #{TOKENS_FILE} )
    system %( ruby #{PROJECT_DIR}/vgparser.rb #{TOKENS_FILE} > #{TREE_FILE} )

    act = File.read(TREE_FILE)
    exp = File.read(project_path("test/gol.vgt.json"))

    if act == exp
      pass
    else
      ts = Time.now.strftime("%Y%m%d_%H%M%S")
      act_file = project_path("tmp/test_result_vgt_#{ts}.txt")
      FileUtils.cp(TREE_FILE, act_file)

      $stderr.print "\n"
      $stderr.puts <<~MSG
        [FAILED] #{self.class.name}##{__method__}
          For detail, run
          diff -u "test/gol.vgt.json" "#{act_file}"
      MSG
      flunk
    end
  end
end
