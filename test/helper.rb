require "minitest/autorun"

PROJECT_DIR = File.expand_path("..", __dir__)

$LOAD_PATH.unshift PROJECT_DIR

def project_path(path)
  File.join(PROJECT_DIR, path)
end
