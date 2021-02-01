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

end

if $0 == __FILE__
  require "json"

  file = ARGV[0]
  tree = JSON.parse(File.read(file))
  FuncallChecker.run(tree)
end
