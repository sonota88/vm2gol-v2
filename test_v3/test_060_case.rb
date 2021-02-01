# coding: utf-8

require_relative "helper"

class Test060 < Minitest::Test

  def setup
    setup_common()
  end

  # --------------------------------

  def test_0
    src = <<~SRC
      def main()
        case
        when (0)
          putchar(#{ "A".ord });
        else
          putchar(#{ "B".ord });
        end
      end
    SRC

    output = run_vm(src)

    assert_equal("B", output)
  end

  def test_1
    src = <<~SRC
      def main()
        case
        when (1)
          putchar(#{ "A".ord });
        else
          putchar(#{ "B".ord });
        end
      end
    SRC

    output = run_vm(src)

    assert_equal("A", output)
  end

  def test_2
    src = <<~SRC
      def main()
        case
        when (2)
          putchar(#{ "A".ord });
        else
          putchar(#{ "B".ord });
        end
      end
    SRC

    output = run_vm(src)

    assert_equal("A", output)
  end

end
