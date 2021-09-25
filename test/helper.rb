require "fileutils"
require "json"
require "minitest/autorun"

PROJECT_DIR = File.expand_path("..", __dir__)

$LOAD_PATH.unshift PROJECT_DIR

def project_path(path)
  File.join(PROJECT_DIR, path)
end

def _system(cmd)
  system cmd
  status = $?
  unless status.success?
    raise "Abnormal exit status (#{status.inspect})"
  end
end

def setup_common
  FileUtils.mkdir_p File.join(PROJECT_DIR, "tmp")
end
