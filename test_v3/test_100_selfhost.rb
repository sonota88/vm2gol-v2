# coding: utf-8

require_relative "helper"

class Test100 < Minitest::Test

  def setup
    setup_common()
  end

  # --------------------------------

  def test_selfhost
    files = [
      "blank_main.pric",
      "hello_world.pric",
      "add.pric",
      "addr_deref.pric"
    ]

    diff_cmd = "ruby " + project_path("selfhost/test/diff.rb")

    files.each do |file|
      file_src = project_path("examples/#{file}")

      asm = compile_to_asm(File.read(file_src))
      file_write(FILE_ASM_RB, asm)

      pricc_pric(file_src, FILE_ASM_PRIC, print_asm: true)

      output, status = _system_v2( %( #{diff_cmd} asm #{FILE_ASM_RB} #{FILE_ASM_PRIC} ) )
      if status.success?
        pass
      else
        puts output
        flunk
      end
    end
  end

end
