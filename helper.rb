require_relative "common"

module Helper

  class FuncallChecker
    def initialize
      @exit_status = 0
    end

    def self.run(tree)
      new.check(tree)
    end

    def collect_fn_sigs(top_stmts)
      top_stmts
        .map { |fn| [fn[1], fn[2].size] }
        .to_h
    end

    def _check(fn_sigs, nodes)
      if nodes[0] == "funcall" || nodes[0] == "call"
        fn_name = nodes[1]
        if fn_sigs.key?(fn_name)
          num_args_exp = fn_sigs[fn_name]
          num_args_act = nodes.size - 2
          if num_args_act != num_args_exp
            $stderr.puts(
              format(
                "ERROR: wrong number of arguments: function %s (given %d, expected %d)",
                fn_name,
                num_args_act,
                num_args_exp
              )
            )
            @exit_status = 1
          end
        else
          $stderr.puts "ERROR: undefined function: " + fn_name
          @exit_status = 1
        end
      end

      nodes.each do |node|
        if node.is_a?(Array)
          _check(fn_sigs, node)
        end
      end
    end

    def check(tree)
      top_stmts = tree[1..-1]
      fn_sigs = collect_fn_sigs(top_stmts)

      # builtin functions
      fn_sigs["getchar"] = 0
      fn_sigs["putchar"] = 1
      fn_sigs["get_sp"] = 0
      fn_sigs["_panic"] = 0
      fn_sigs["_debug"] = 0

      _check(fn_sigs, tree)

      if @exit_status != 0
        exit @exit_status
      end
    end
  end

  def self.check_gvar_width(file)
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
      raise "ERROR: #{file}: total (#{gs_total}) declared (#{declared_size})"
    end
  end

end

cmd = ARGV.shift
case cmd
when "fn-sig"
  require "json"
  file = ARGV[0]
  tree = JSON.parse(File.read(file))
  Helper::FuncallChecker.run(tree)
when "gvar-width"
  file = ARGV[0]
  Helper.check_gvar_width(file)
else
  raise "invalid command"
end
