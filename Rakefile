require "fileutils"

task default: %i[pack_dicey pack_vector_number]

desc "Download and pack dicey gem"
task pack_dicey: %i[download_dicey] do
  sh "cd tmp/dicey && ../../pack_gem"
  sh "cp tmp/dicey/tmp/dicey.pack.rb public/dicey.pack.rb"
end
desc "Download dicey gem (depth 1)"
task :download_dicey do
  FileUtils.rm_rf "tmp/dicey"
  FileUtils.mkdir_p "tmp/dicey"
  sh "git clone --depth 1 https://github.com/trinistr/dicey tmp/dicey"
end

desc "Download and pack vector_number gem"
task pack_vector_number: %i[download_vector_number] do
  sh "cd tmp/vector_number && ../../pack_gem"
  sh "cp tmp/vector_number/tmp/vector_number.pack.rb public/vector_number.pack.rb"
end
desc "Download vector_number gem (depth 1)"
task :download_vector_number do
  FileUtils.rm_rf "tmp/vector_number"
  FileUtils.mkdir_p "tmp/vector_number"
  sh "git clone --depth 1 https://github.com/trinistr/vector_number tmp/vector_number"
end
