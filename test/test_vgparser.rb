require_relative "../vgparser"
require "minitest/autorun"

class ParserTest < Minitest::Test

  def test_func_1
    src = <<-EOS
      func f1(){}
    EOS

    tree_exp = [
      :stmts,
      [:func, "f1", [], []]]

    tree_act = parse(src)

    assert_equal(format(tree_exp), format(tree_act))
  end

  def test_func_2
    src = <<-EOS
      func f1(a, b){}
    EOS

    tree_exp = [
      :stmts,
      [:func, "f1", ["a", "b"], []]]

    tree_act = parse(src)

    assert_equal(format(tree_exp), format(tree_act))
  end

  # --------------------------------

  def test_return_1
    src = <<-EOS
      return;
    EOS

    tree_exp = [
      [:return]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_return_2
    src = <<-EOS
      return 1;
    EOS

    tree_exp = [
      [:return, 1]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_return_3
    src = <<-EOS
      return vram[vi];
    EOS

    tree_exp = [
      [:return, "vram[vi]"]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  # --------------------------------

  def test_var_1
    src = <<-EOS
      var a;
    EOS

    tree_exp = [
      [:var, "a"]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_var_init_1
    src = <<-EOS
      var a = 1;
    EOS

    tree_exp = [
      [:var, "a", 1]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_var_init_2
    src = <<-EOS
      var a = 1 + 2;
    EOS

    tree_exp = [
      [:var, "a", [:+, 1, 2]]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_var_init_3
    src = <<-EOS
      var b = a;
    EOS

    tree_exp = [
      [:var, "b", "a"]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_var_init_4
    src = <<-EOS
      var a = ((b * c) + d) + e;
    EOS

    tree_exp = [
      [:var, "a",
       [:+,
          [:+,
             [:*, "b", "c"],
           "d"],
        "e"]]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  # --------------------------------

  def test_set_1
    src = <<-EOS
      set a = 1;
    EOS

    tree_exp = [
      [:set, "a", 1]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_set_2
    src = <<-EOS
      set a = b;
    EOS

    tree_exp = [
      [:set, "a", "b"]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_set_3
    src = <<-EOS
      set vram[vi] = b;
    EOS

    tree_exp = [
      [:set, "vram[vi]", "b"]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  # --------------------------------

  def test_call_1
    src = <<-EOS
      call foo();
    EOS

    tree_exp = [
      [:call, "foo"]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_call_2
    src = <<-EOS
  call foo(a, 1);
    EOS

    tree_exp = [
      [:call, "foo", "a", 1]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  # --------------------------------

  def test_call_set_1
    src = <<-EOS
      call_set a = f2();
    EOS

    tree_exp = [
      [:call_set, "a",
       ["f2"]]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_call_set_2
    src = <<-EOS
      call_set a = f2(a, 1);
    EOS

    tree_exp = [
      [:call_set, "a",
       ["f2", "a", 1]]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  # --------------------------------

  def test_while_1
    src = <<-EOS
      while (a == 1) {}
    EOS

    tree_exp = [
      [:while, [:eq, "a", 1], []]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_while_2
    src = <<-EOS
      while (a == 1) {
        var b;
      }
    EOS

    tree_exp = [
      [:while, [:eq, "a", 1], [
         [:var, "b"]]]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_while_3
    src = <<-EOS
      case {
        (a == b) {
          var c;
        }
      }
    EOS

    tree_exp = [
      [:case,
       [[:eq, "a", "b"],
        [:var, "c"]]]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_while_4
    src = <<-EOS
      while (a != b) {}
    EOS

    tree_exp = [
      [:while,
       [:neq, "a", "b"],
       []]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  # --------------------------------

  def test_case_1
    src = <<-EOS
      case {
        (1){ var a; }
      }
    EOS

    tree_exp = [
      [:case,
       [1, [:var, "a"]]]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_case_2
    src = <<-EOS
      case {
        (1){ var a; }
        (2){ var b; }
      }
    EOS

    tree_exp = [
      [:case,
       [1, [:var, "a"]],
       [2, [:var, "b"]]]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_case_3
    src = <<-EOS
      case {
        (a == 1){ var b; }
      }
    EOS

    tree_exp = [
      [:case,
       [[:eq, "a", 1], [:var, "b"]]]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  # --------------------------------

  def test_cmt
    src = <<-EOS
      _cmt("vm comment");
    EOS

    tree_exp = [
      [:_cmt, "vm comment"]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  # --------------------------------

  def parse(src)
    tokens = tokenize(src)
    Parser.new(tokens).parse()
  end

  def format(tree)
    JSON.pretty_generate(tree)
  end

  def parse_stmts(src)
    wrapped_src = <<-EOS
      func test(){
        #{src}
      }
    EOS

    tokens = tokenize(wrapped_src)
    Parser.new(tokens).parse()
  end

  def format_stmts(tree)
    func = tree[1]
    body = func[3]
    JSON.pretty_generate(body)
  end

end
