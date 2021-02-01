# coding: utf-8

require_relative "helper"

class Test040 < Minitest::Test

  def setup
    setup_common()
  end

  # --------------------------------

  # 渡した先の関数で読む
  def test_call_read
    src = <<~SRC
      def f(a_, b_)
        var x;
        _cmt("==>>");
        x = *(a_);
        _cmt("<<==");
        putchar(x);

        x = *(b_);
        putchar(x);
      end

      def main()
        var a = 65;
        var a_ = &a;
        var b = 66;
        var b_ = &b;
        f(a_, b_);
      end
    SRC

    output = run_vm(src)

    assert_equal(
      "AB",
      output
    )
  end

  # 渡した先の関数で値を変更
  def test_call_write
    src = <<~SRC
      def f(a_)
        *(a_) = 66;
      end

      def main()
        var a = 65;
        putchar(a);

        var a_ = &a;
        f(a_);

        putchar(a);
      end
    SRC

    output = run_vm(src)

    assert_equal(
      "AB",
      output
    )
  end

  # 足し算の結果を代入
  def test_deref_lhs_expr
    src = <<~SRC
      def main()
        var [1]xs;
        var x0;

        *(&xs + 0) = 65 + 1;

        x0 = *(&xs + 0);
        putchar(x0);
      end
    SRC

    output = run_vm(src)

    assert_equal(
      "B",
      output
    )
  end

end
