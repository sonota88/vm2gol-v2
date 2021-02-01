# coding: utf-8

require_relative "helper"

class Test010 < Minitest::Test

  def setup
    setup_common()
  end

  # --------------------------------

  def test_hello_world
    src = <<~SRC
      def main()
        putchar(#{ "H".ord  });
        putchar(#{ "e".ord  });
        putchar(#{ "l".ord  });
        putchar(#{ "l".ord  });
        putchar(#{ "o".ord  });
        putchar(#{ ",".ord  });
        putchar(#{ " ".ord  });
        putchar(#{ "w".ord  });
        putchar(#{ "o".ord  });
        putchar(#{ "r".ord  });
        putchar(#{ "l".ord  });
        putchar(#{ "d".ord  });
        putchar(#{ "\n".ord });
      end
    SRC

    file_write(FILE_SRC, src)

    # compile and assemble
    build(FILE_SRC, FILE_EXE)

    output = _system(%( ruby #{PROJECT_DIR}/vgvm.rb #{FILE_EXE} ))

    assert_equal("Hello, world\n", output)
  end

  def test_cat
    src = <<~SRC
      def main()
        var n;

        while (n != -1)
          n = getchar();

          case
          when (n != -1)
            putchar(n);
          end
        end
      end
    SRC

    file_write(FILE_SRC, src)

    # compile and assemble
    build(FILE_SRC, FILE_EXE)

    file_write(FILE_STDIN, "abc" + LF + "123" + LF)
    output = _system(%( ruby #{PROJECT_DIR}/vgvm.rb #{FILE_EXE} ))

    assert_equal("abc" + LF + "123" + LF, output)
  end

end
