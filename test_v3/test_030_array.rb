# coding: utf-8

require_relative "helper"

class Test030 < Minitest::Test

  def setup
    setup_common()
  end

  # --------------------------------

  def test_array
    src = <<~SRC
      def main()
        var a;
        var [2]b;
        var c;

        a         = 65; # A
        *(&b)     = 66; # B
        *(&b + 1) = 67; # C
        c         = 68; # D

        putchar(a);
        putchar(*(&b));
        putchar(*(&b + 1));
        putchar(c);
      end
    SRC

    output = run_vm(src)

    assert_equal(
      "ABCD",
      output
    )
  end

end
