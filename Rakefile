require "rake/testtask"

Rake::TestTask.new(:test_v2) do |t|
  t.test_files = FileList["test/**/test_*.rb"]
end

Rake::TestTask.new(:test_v3) do |t|
  t.test_files = FileList["test_v3/**/test_*.rb"]
end

task :default => :test_v3
