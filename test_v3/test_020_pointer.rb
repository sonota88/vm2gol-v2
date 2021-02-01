# coding: utf-8

require_relative "helper"

class Test020 < Minitest::Test

  def setup
    setup_common()
  end

  # --------------------------------

  def test_addr
    src = <<~SRC
      def main()
        var a;
        var b_;
        b_ = &a;
      end
    SRC

    output = run_vm(src)

    assert_equal("", output)
  end

  def test_addr_asm
    src = <<~SRC
      def main()
        var a;
        var b_;
        b_ = &a;
      end
    SRC

    expected = <<-ASM
  sub_sp 1
  sub_sp 1
  lea reg_a [bp:-1]  # dest src
  push reg_a
  pop reg_a
  cp reg_a [bp:-2]
    ASM

    actual = compile_to_asm(src)

    assert_equal(
      expected,
      extract_asm_main_body(actual)
    )
  end

  def test_deref_lhs
    src = <<~SRC
      def main()
        var a;  # bp-1
        var b_; # bp-2
        _cmt("b_ = &a");
        b_ = &a;
        _cmt("*(b_) = 65");
        *(b_) = 65; # A
        putchar(a);
      end
    SRC

    output = run_vm(src)

    assert_equal("A", output)
  end

  def test_deref_lhs_asm
    src = <<~SRC
      def main()
        var a;  # bp-1
        var b_; # bp-2
        b_ = &a;
        *(b_) = 65; # A
      end
    SRC

    expected = <<-ASM
  sub_sp 1
  sub_sp 1
  lea reg_a [bp:-1]  # dest src
  push reg_a
  pop reg_a
  cp reg_a [bp:-2]
  cp 65 reg_a
  push reg_a
  cp [bp:-2] reg_a
  pop reg_b
  cp reg_b [reg_a]
    ASM

    actual = compile_to_asm(src)

    assert_equal(
      expected,
      extract_asm_main_body(actual)
    )
  end

  def test_deref_rhs
    src = <<~SRC
      def main()
        var a = 65;
        var b_;
        var c;

        _cmt("b_ = &a");
        b_ = &a;
        _cmt("c = *(b_)");
        c = *(b_);
        _cmt("putc");
        putchar(c);
      end
    SRC

    output = run_vm(src)

    assert_equal("A", output)
  end

  # *(&x + N)
  def test_deref_rhs_calc_addr
    src = <<~SRC
      def main()
        var [4]xs; # bp-1..-4
        var x;     # bp-5

        _cmt("-->> *(&xs + 0) = 65");
        *(&xs + 0) = 65;

        _cmt("-->> *(&xs + 3) = 66");
        *(&xs + 3) = 66;

        x = *(&xs + 0);
        putchar(x);
        x = *(&xs + 3);
        putchar(x);
      end
    SRC

    output = run_vm(src)

    assert_equal("AB", output)
  end

  # *(x_ + N)
  def test_deref_rhs_calc_ptr
    src = <<~SRC
      def main()
        var [4]xs;
        var xs_;
        var x;

        xs_ = &xs;

        *(xs_ + 0) = 65;
        *(xs_ + 3) = 68;

        x = *(xs_ + 0);
        putchar(x);
        x = *(xs_ + 3);
        putchar(x);
      end
    SRC

    output = run_vm(src)

    assert_equal("AD", output)
  end

  # *(x_ + lvar)
  def test_deref_rhs_calc_lvar
    src = <<~SRC
      def main()
        var [4]xs;
        var xs_;
        var x;
        var i = 1;

        xs_ = &xs;

        *(xs_ + 0) = 65;
        *(xs_ + 1) = 66;

        x = *(xs_ + i);

        putchar(x);
      end
    SRC

    output = run_vm(src)

    assert_equal("B", output)
  end

end
