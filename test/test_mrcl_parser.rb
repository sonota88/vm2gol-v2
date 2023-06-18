require_relative "helper"

class ParserTest < Minitest::Test
  VG_FILE     = project_path("tmp/test.vg.txt")
  TOKENS_FILE = project_path("tmp/test.tokens.txt")
  TREE_FILE   = project_path("tmp/test.vgt.json")

  def setup
    setup_common
  end

  # --------------------------------

  def test_func_1
    src = <<-EOS
      func f1(): void {}
    EOS

    tree_exp = [
      :top_stmts,
      [:func, "f1", "void", [], []]]

    tree_act = parse(src)

    assert_equal(format(tree_exp), format(tree_act))
  end

  def test_func_2
    src = <<-EOS
      func f1(): void {}
      func f2(): void {}
    EOS

    tree_exp = [
      :top_stmts,
      [:func, "f1", "void", [], []],
      [:func, "f2", "void", [], []]]

    tree_act = parse(src)

    assert_equal(format(tree_exp), format(tree_act))
  end

  def test_func_3
    src = <<-EOS
      func f1(a: int, b: int, c: int): void {}
    EOS

    tree_exp = [
      :top_stmts,
      [:func, "f1", "void", [
         ["a", "int"],
         ["b", "int"],
         ["c", "int"]
       ],
       []]]

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

  # --------------------------------

  def test_expr_1
    src = <<-EOS
      return 1 + 2;
    EOS

    tree_exp = [
      [:return, [:+, 1, 2]]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_expr_paren
    src = <<-EOS
      return ((b * c) + d) + e;
    EOS

    tree_exp = [
      [:return,
       [:+,
          [:+,
             [:*, "b", "c"],
           "d"],
        "e"]]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_expr_left_assoc
    src = <<-EOS
      return 1 + 2 + 3;
    EOS

    tree_exp = [
      [:return,
       ["+".to_sym,
        ["+".to_sym, 1, 2],
        3]]]

    tree_act = parse_stmts(src)

    assert_equal(
      format(tree_exp),
      format_stmts(tree_act)
    )
  end

  # --------------------------------

  def test_var_1
    src = <<-EOS
      var a: int;
    EOS

    tree_exp = [
      [:var, ["a", "int"]]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_var_init_1
    src = <<-EOS
      var a: int = 1;
    EOS

    tree_exp = [
      [:var, ["a", "int"], 1]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_var_init_2
    src = <<-EOS
      var b: int = a;
    EOS

    tree_exp = [
      [:var, ["b", "int"], "a"]]

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

  # --------------------------------

  def test_call_1
    src = <<-EOS
      call foo();
    EOS

    tree_exp = [
      [:call, ["foo"]]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_call_2
    src = <<-EOS
      call foo(a, 1);
    EOS

    tree_exp = [
      [:call, ["foo", "a", 1]]]

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
      [:while, ["==".to_sym, "a", 1], []]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_while_2
    src = <<-EOS
      var a: int;
      while (a == 1) {
        set a = 2;
      }
    EOS

    tree_exp = [
      [:var, ["a", "int"]],
      [:while, ["==".to_sym, "a", 1], [
         [:set, "a", 2]]]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_while_3
    src = <<-EOS
      while (a != b) {}
    EOS

    tree_exp = [
      [:while,
       ["!=".to_sym, "a", "b"],
       []]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  # --------------------------------

  def test_case_1
    src = <<-EOS
      var a: int;
      case
      when (1) { set a = 2; }
    EOS

    tree_exp = [
      [:var, ["a", "int"]],
      [:case,
       [1, [:set, "a", 2]]]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_case_2
    src = <<-EOS
      var a: int;
      case
      when (1) { set a = 3; }
      when (2) { set a = 4; }
    EOS

    tree_exp = [
      [:var, ["a", "int"]],
      [:case,
       [1, [:set, "a", 3]],
       [2, [:set, "a", 4]]]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  def test_case_3
    src = <<-EOS
      var a: int;
      case
      when (a == 1) { set a = 2; }
    EOS

    tree_exp = [
      [:var, ["a", "int"]],
      [:case,
       [["==".to_sym, "a", 1], [:set, "a", 2]]]]

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

  def test_debug
    src = <<-EOS
      _debug();
    EOS

    tree_exp = [
      [:_debug]]

    tree_act = parse_stmts(src)

    assert_equal(format(tree_exp), format_stmts(tree_act))
  end

  # --------------------------------

  def parse(src)
    File.open(VG_FILE, "wb") { |f| f.print src }
    _system %( ruby #{PROJECT_DIR}/mrcl_lexer.rb  #{VG_FILE} > #{TOKENS_FILE} )
    _system %( ruby #{PROJECT_DIR}/mrcl_parser.rb #{TOKENS_FILE} > #{TREE_FILE} )
    json = File.read(TREE_FILE)
    JSON.parse(json)
  end

  def format(tree)
    JSON.pretty_generate(tree)
  end

  def parse_stmts(src)
    wrapped_src = <<-EOS
      func test(): void {
        #{src}
      }
    EOS

    parse(wrapped_src)
  end

  def format_stmts(tree)
    # (func name rt args body)
    func = tree[1]
    body = func[4]
    JSON.pretty_generate(body)
  end
end
