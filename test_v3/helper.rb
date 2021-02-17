require "fileutils"
require "minitest/autorun"

PROJECT_DIR = File.expand_path("..", __dir__)

$LOAD_PATH.unshift PROJECT_DIR

LF = "\n"

def project_path(path)
  File.join(PROJECT_DIR, path)
end

def _system(cmd)
  out = `#{cmd}`
  status = $?
  unless status.success?
    raise "Abnormal exit status (#{status.inspect})"
  end
  out
end

def _system_v2(cmd)
  out = `#{cmd}`
  status = $?
  [out, status]
end

def setup_common
  Dir.chdir PROJECT_DIR
  FileUtils.mkdir_p File.join(PROJECT_DIR, "tmp")
  file_write(FILE_STDIN, "")
end

def file_write(path, text)
  File.open(path, "wb") { |f| f.write text }
end

def extract_asm_main_body(asm)
  lines = []
  in_body = false
  asm.each_line { |line|
    if line.chomp == "  # <<-- main body"
      in_body = false
    end

    if in_body
      lines << line
    end

    if line.chomp == "  # -->> main body"
      in_body = true
    end
  }
  lines.join("")
end

FILE_STDIN  = project_path("tmp/stdin")
FILE_SRC    = project_path("tmp/test.vg.txt")
FILE_TOKENS = project_path("tmp/test.tokens.txt")
FILE_TREE   = project_path("tmp/test.vgt.json")
FILE_ASM    = project_path("tmp/test.vga.txt")
FILE_EXE    = project_path("tmp/test.vge.txt")
FILE_ASM_RB = project_path("tmp/test_rb.vga.txt")
FILE_ASM_PRIC = project_path("tmp/test_pric.vga.txt")
FILE_OUTPUT = project_path("tmp/output.txt")

def compile_to_asm(src)
  infile = FILE_SRC
  file_write(infile, src)
  _system %( ruby #{PROJECT_DIR}/vglexer.rb  #{infile     } > #{FILE_TOKENS} )
  _system %( ruby #{PROJECT_DIR}/vgparser.rb #{FILE_TOKENS} > #{FILE_TREE  } )
  _system %( ruby #{PROJECT_DIR}/vgcg.rb     #{FILE_TREE  } )
end

def build(infile, outfile)
  _system %( ruby #{PROJECT_DIR}/vglexer.rb  #{infile     } > #{FILE_TOKENS} )
  _system %( ruby #{PROJECT_DIR}/vgparser.rb #{FILE_TOKENS} > #{FILE_TREE  } )
  _system %( ruby #{PROJECT_DIR}/vgcg.rb     #{FILE_TREE  } > #{FILE_ASM   } )
  _system %( ruby #{PROJECT_DIR}/vgasm.rb    #{FILE_ASM   } > #{outfile    } )
end

def pricc_rb(infile, outfile, print_asm: false)
  cmd = [
    project_path("pricc"),
    infile,
    "> #{outfile}"
  ].join(" ")

  cmd = "PRINT_ASM=1 " + cmd if print_asm

  Dir.chdir(project_path("./")) do
    _system cmd
  end
end

def pricc_pric(infile, outfile, print_asm: false)
  cmd = [
    project_path("selfhost/pricc"),
    infile,
    "> #{outfile}"
  ].join(" ")

  cmd = "PRINT_ASM=1 " + cmd if print_asm

  Dir.chdir(project_path("selfhost/")) do
    _system cmd
  end
end

def run_vm(src, stdin: "")
  file_write(FILE_SRC, src)

  # compile and assemble
  build(FILE_SRC, FILE_EXE)

  file_write(FILE_STDIN, stdin)
  _system(%( ruby #{PROJECT_DIR}/vgvm.rb #{FILE_EXE} ))
end
