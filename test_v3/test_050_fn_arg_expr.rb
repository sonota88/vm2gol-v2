# coding: utf-8

require_relative "helper"

class Test050 < Minitest::Test

  def setup
    setup_common()
  end

  # --------------------------------

  # 引数なしの場合
  def test_fn_arg_empty
    src = <<~SRC
      def f()
        putchar(65);
      end

      def main()
        f();
      end
    SRC

    output = run_vm(src)

    assert_equal(
      "A",
      output
    )
  end

  # 関数の引数に式を渡す
  def test_fn_arg_add
    src = <<~SRC
      def f(a)
        putchar(a);
      end

      def main()
        f(65 + 1);
      end
    SRC

    output = run_vm(src)

    assert_equal(
      "B",
      output
    )
  end

  # 関数の引数に式を渡す: addr
  def test_fn_arg_addr
    src = <<~SRC
      def f(a_)
        var x;
        x = *(a_);
        putchar(x);
      end

      def main()
        var a = 67;
        f(&a);
      end
    SRC

    output = run_vm(src)

    assert_equal(
      "C",
      output
    )
  end

end
