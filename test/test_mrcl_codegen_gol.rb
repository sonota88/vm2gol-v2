require_relative "./helper"

class VgcgGolTest < Minitest::Test
  ASM_FILE = project_path("tmp/test_mrcl_asm_gol.vga.txt")

  def setup
    setup_common()
  end

  def test_gol
    system %( ruby #{PROJECT_DIR}/mrcl_codegen.rb #{PROJECT_DIR}/test/gol.vgt.json > #{ASM_FILE} )

    act = File.read(ASM_FILE)
    exp = File.read(project_path("test/gol.vga.txt"))

    if act == exp
      pass
    else
      ts = Time.now.strftime("%Y%m%d_%H%M%S")
      act_file = project_path("tmp/test_result_vga_#{ts}.txt")
      FileUtils.cp(ASM_FILE, act_file)

      $stderr.print "\n"
      $stderr.puts <<~MSG
        [FAILED] #{self.class.name}##{__method__}
          For detail, run
          diff -u "test/gol.vga.txt" "#{act_file}"
      MSG
      flunk
    end
  end
end
