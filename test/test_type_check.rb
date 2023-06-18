require_relative "helper"
require "type_check"

class TypeCheckTest < Minitest::Test
  def test_int_1
    ast = [
      "top_stmts",
      ["func", "main", "void", [], [
         ["var", ["a", "int"]],
         ["set", "a", 1]
       ]]
    ]

    check(ast)
  end

  def test_int_2
    ast = [
      "top_stmts",
      ["func", "main", "void", [], [
         ["var", ["a", "int"]],
         ["set", "a", ["==", 1, 1]]
       ]]
    ]

    begin
      check(ast)
      flunk
    rescue TypeError
      # ok
    end
  end

  def test_bool_1
    ast = [
      "top_stmts",
      ["func", "main", "void", [], [
         ["var", ["a", "bool"]],
         ["set", "a", ["==", 1, 1]]
       ]]
    ]

    check(ast)
  end

  def test_bool_2
    ast = [
      "top_stmts",
      ["func", "main", "void", [], [
         ["var", ["a", "bool"]],
         ["set", "a", 1]
       ]]
    ]

    begin
      check(ast)
      flunk
    rescue TypeError
      # ok
    end
  end

  def test_fn_arg_1
    ast = [
      "top_stmts",
      ["func", "f", "void", [
         ["a", "int"]
       ], [
         ["var", ["b", "int"]],
         ["set", "b", "a"]
       ]]
    ]

    check(ast)
  end

  def test_fn_arg_2
    ast = [
      "top_stmts",
      ["func", "f", "void", [
         ["a", "int"]
       ], [
         ["var", ["b", "bool"]],
         ["set", "b", "a"]
       ]]
    ]

    begin
      check(ast)
      flunk
    rescue TypeError
      # ok
    end
  end

  def test_while_1
    ast = [
      "top_stmts",
      ["func", "main", "void", [], [
         ["while", ["==", 1, 2], []]
       ]]
    ]

    check(ast)
  end

  def test_while_2
    ast = [
      "top_stmts",
      ["func", "main", "void", [], [
         ["while", 1, []]
       ]]
    ]

    begin
      check(ast)
      flunk
    rescue TypeError
      # ok
    end
  end

  def test_case_1
    ast = [
      "top_stmts",
      ["func", "main", "void", [], [
         ["case",
          [["==", 1, 2], []],
          [["==", 1, 3], []]
         ]
       ]]
    ]

    check(ast)
  end

  def test_case_2
    ast = [
      "top_stmts",
      ["func", "main", "void", [], [
         ["while", 3,
          ["return"]
         ]
       ]]
    ]

    begin
      check(ast)
      flunk
    rescue TypeError
      # ok
    end
  end

  # --------------------------------

  def test_binop_int
    ast = [
      "top_stmts",
      ["func", "main", "void", [], [
         ["var", ["a", "bool"], ["==", 1, 2]],
         ["return", ["+", 1, "a"]]
       ]]
    ]

    begin
      check(ast)
      flunk
    rescue TypeError
      # ok
    end
  end

  # TODO test_binop ==, !=

  # --------------------------------

  def test_funcall_args
    ast = [
      "top_stmts",
      ["func", "f1", "void", [["a", "bool"]], [
         ["return", 1]
       ]],
      ["func", "main", "void", [], [
         ["call", "f1", 1]
       ]]
    ]

    begin
      check(ast)
      flunk
    rescue TypeError
      # ok
    end
  end

  # --------------------------------

  def test_funcall_retval_1
    ast = [
      "top_stmts",
      ["func", "main", "bool", [], [
         ["return", 1]
       ]]
    ]

    begin
      check(ast)
      flunk
    rescue TypeError
      # ok
    end
  end

  # void なのに値を返そうとしている
  def test_funcall_retval_2
    ast = [
      "top_stmts",
      ["func", "main", "void", [], [
         ["return", 1]
       ]]
    ]

    begin
      check(ast)
      flunk
    rescue TypeError
      # ok
    end
  end

  def test_funcall_retval_3
    ast = [
      "top_stmts",
      ["func", "f1", "int", [], [
         ["return", 1]
       ]],
      ["func", "main", "void", [], [
         ["var", ["a", "bool"]],
         ["call_set", "a", ["f1"]]
       ]]
    ]

    begin
      check(ast)
      flunk
    rescue TypeError
      # ok
    end
  end

  def test_call_args
    ast = [
      "top_stmts",
      ["func", "f1", "void", [["a", "bool"]], [
       ]],
      ["func", "main", "void", [], [
         ["call", ["f1", 1]]
       ]]
    ]

    begin
      check(ast)
      flunk
    rescue TypeError
      # ok
    end
  end

  # ret type
  def test_call_set_1
    ast = [
      "top_stmts",
      ["func", "f1", "void", [], [
       ]],
      ["func", "main", "void", [], [
         ["var", ["a", "bool"]],
         ["call_set", "a", ["f1"]]
       ]]
    ]

    begin
      check(ast)
      flunk
    rescue TypeError
      # ok
    end
  end

  # num args
  def test_call_set_2
    ast = [
      "top_stmts",
      ["func", "f1", "int", [["b", "int"]], [
       ]],
      ["func", "main", "void", [], [
         ["var", ["a", "int"]],
         ["call_set", "a", ["f1"]]
       ]]
    ]

    begin
      check(ast)
      flunk
    rescue
      # ok
    end
  end

  # arg type
  def test_call_set_3
    ast = [
      "top_stmts",
      ["func", "f1", "bool", [["a", "bool"]], [
       ]],
      ["func", "main", "void", [], [
         ["var", ["a", "bool"]],
         ["call_set", "a", ["f1", 1]]
       ]]
    ]

    begin
      check(ast)
      flunk
    rescue TypeError => e
      assert_equal("expected (bool) actual (int)", e.message)
    end
  end

  def test_return
    ast = [
      "top_stmts",
      ["func", "main", "void", [], [
         ["return", 1]
       ]]
    ]

    begin
      check(ast)
      flunk
    rescue TypeError => e
      assert_equal("expected (void) actual (int)", e.message)
    end
  end

  def test_return_var
    ast = [
      "top_stmts",
      ["func", "f1", "void", [], [
         ["var", ["a", "int"], 1],
         ["return", "a"]
       ]],
      ["func", "main", "void", [], [
       ]]
    ]

    begin
      check(ast)
      flunk
    rescue TypeError => e
      assert_equal("expected (void) actual (int)", e.message)
    end
  end
end
