# coding: utf-8

require_relative "helper"

class Test030 < Minitest::Test

  LF = "\n"

  def setup
    setup_common()
  end

  # --------------------------------

  # def test_array_asm
  #   src = <<~SRC
  #     def main()
  #       var [4]xs;
  #       xs[0] = 65;
  #       xs[3] = 68;
  #     end
  #   SRC
  # 
  #   expected = <<-ASM
  # sub_sp 4
  # cp 65 reg_a
  # cp reg_a [bp:-4:0]
  # cp 68 reg_a
  # cp reg_a [bp:-4:3]
  #   ASM
  # 
  #   actual = compile_to_asm(src)
  # 
  #   assert_equal(
  #     expected,
  #     extract_asm_main_body(actual)
  #   )
  # end
  # 
  # def test_array_asm_2
  #   src = <<~SRC
  #     def main()
  #       var [4]xs;
  #       var x;
  #       xs[0] = 65;
  #       xs[3] = 68;
  #       x = xs[0];
  #       x = xs[3];
  #     end
  #   SRC
  # 
  #   expected = <<-ASM
  # sub_sp 4
  # sub_sp 1
  # cp 65 [bp:-4:0]
  # cp 68 [bp:-4:3]
  # lea reg_a [bp:-4:0]  # dest src
  # cp [reg_a:0:0] reg_a
  # cp reg_a [bp-5]
  # lea reg_a [bp:-4:0]  # dest src
  # cp [reg_a:0:3] reg_a
  # cp reg_a [bp-5]
  #   ASM
  # 
  #   actual = compile_to_asm(src)
  # 
  #   assert_equal(
  #     expected,
  #     extract_asm_main_body(actual)
  #   )
  # end
  # 
  # def test_array
  #   src = <<~SRC
  #     def main()
  #       var [4]xs;
  #       var x;
  #       xs[0] = 65;
  #       xs[3] = 68;
  #       x = xs[0];
  #       putchar(x);
  #       x = xs[3];
  #       putchar(x);
  #     end
  #   SRC
  # 
  #   output = run_vm(src)
  # 
  #   assert_equal(
  #     "AD",
  #     output
  #   )
  # end

end
