require "minitest/autorun"

class TestGlobalVariable < Minitest::Test

  def test_global_variables_width
    errs = []

    %w(lexer parser codegen).each { |name|
      file = File.join(__dir__, "../#{name}.pric")

      gs_total = 0
      gs_total += 1 # alloc cursor

      declared_size = 0

      File.read(file).each_line { |line|
        case line
        when /^def GS_.+ return (\d+);/
          gs_total += $1.to_i
        when /var \[(\d+)\]g;/
          declared_size = $1.to_i
        end
      }

      if declared_size != gs_total
        errs << "#{name}: total (#{gs_total}) declared (#{declared_size})"
      end
    }

    assert_equal([], errs)
  end

end
