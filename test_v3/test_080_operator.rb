# coding: utf-8

require_relative "helper"

class Test080 < Minitest::Test

  def setup
    setup_common()
  end

  # --------------------------------

  def test_lt
    src = <<~SRC
      def main()
        case when (1 < 2)
          putchar(65); # A
        else
          putchar(66); # B
        end

        case when (2 < 2)
          putchar(67); # C
        else
          putchar(68); # D
        end

        case when (3 < 2)
          putchar(69); # E
        else
          putchar(70); # F
        end
      end
    SRC

    output = run_vm(src)

    assert_equal("ADF", output)
  end

end
