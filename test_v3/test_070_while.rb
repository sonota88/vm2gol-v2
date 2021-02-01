# coding: utf-8

require_relative "helper"

class Test070 < Minitest::Test

  def setup
    setup_common()
  end

  # --------------------------------

  def X_test_while
    src = <<~SRC
      def main()
        var i = 0;

        while (2)
          i = i + 1;
        end
      end
    SRC

    run_vm(src)
  end

end
