require_relative "helper"

class VgasmGolTest < Minitest::Test
  EXE_FILE = project_path("tmp/test_mrcl_asm_gol.vge.txt")

  def setup
    setup_common()
  end

  def test_gol
    system %( ruby #{PROJECT_DIR}/mrcl_asm.rb #{PROJECT_DIR}/test/gol.vga.txt > #{EXE_FILE} )

    act = File.read(EXE_FILE)
    exp = File.read(project_path("test/gol.vge.txt"))

    if act == exp
      pass
    else
      ts = Time.now.strftime("%Y%m%d_%H%M%S")
      act_file = project_path("tmp/test_result_vga_#{ts}.txt")
      FileUtils.cp(EXE_FILE, act_file)

      $stderr.print "\n"
      $stderr.puts <<~MSG
        [FAILED] #{self.class.name}##{__method__}
          For detail, run
          diff -u "test/gol.vge.txt" "#{act_file}"
      MSG
      flunk
    end
  end
end
