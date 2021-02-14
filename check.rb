require_relative "common"

module Checker

  class FuncallChecker
    def initialize
      @exit_status = 0
    end

    def self.run(tree)
      new.check(tree)
    end

    def collect_fn_sigs(top_stmts)
      top_stmts
        .map { |fn| [fn[1], fn[2]] }
        .to_h
    end

    def _check(fn_sigs, nodes)
      if nodes[0] == "funcall" || nodes[0] == "call"
        fn_name = nodes[1]
        if fn_sigs.key?(fn_name)
          num_args_exp = fn_sigs[fn_name].size
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
            $stderr.puts "  expected arguments: " + fn_sigs[fn_name].join(", ")
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
      fn_sigs["getchar"] = []
      fn_sigs["putchar"] = ["char"]
      fn_sigs["get_sp" ] = []
      fn_sigs["_panic" ] = []
      fn_sigs["_debug" ] = []
      fn_sigs["set_vram" ] = ["vram_addr", "value"]
      fn_sigs["get_vram" ] = ["vram_addr"]

      _check(fn_sigs, tree)

      if @exit_status != 0
        exit @exit_status
      end
    end
  end

  def self.check_gvar_width(file)
    gs_total = 0
    gs_total += 1 # alloc cursor

    declared_size = nil

    File.read(file).each_line { |line|
      case line
      when /^def GS_.+ return (\d+);/
        gs_total += $1.to_i
      when /var \[(\d+)\]g;/
        declared_size = $1.to_i
      end
    }

    if declared_size
      if declared_size != gs_total
        raise "ERROR: #{file}: total (#{gs_total}) declared (#{declared_size})"
      end
    else
      # OK: グローバル変数を使っていない
    end
  end

end

cmd = ARGV.shift
case cmd
when "fn-sig"
  require "json"
  file = ARGV[0]
  tree = JSON.parse(File.read(file))
  Checker::FuncallChecker.run(tree)
when "gvar-width"
  file = ARGV[0]
  Checker.check_gvar_width(file)
else
  raise "invalid command"
end
