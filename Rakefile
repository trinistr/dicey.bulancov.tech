require "fileutils"

task default: %i[download_and_pack_gems]

REMOTE_GEMS = {
  "dicey" => "https://github.com/trinistr/dicey",
  "vector_number" => "https://github.com/trinistr/vector_number",
}.freeze

LOCAL_GEMS = {
  "dicey" => "../dicey",
  "vector_number" => "../vector_number",
}.freeze

desc "Download and pack dicey and vector_number gems"
task :download_and_pack_gems do
  REMOTE_GEMS.keys.each do |gem|
    Rake::Task[:download_gem].execute(gem_name: gem)
    Rake::Task[:pack_gem].execute(gem_path: "tmp/#{gem}")
  end
end

desc "Pack dicey and vector_number from sibling directories"
task :pack_local_gems do
  LOCAL_GEMS.keys.each do |gem|
    Rake::Task[:pack_gem].invoke(LOCAL_GEMS[gem])
  end
end

desc "Download a gem from remote repository to tmp/"
task :download_gem, [:gem_name] do |_, args|
  gem = args[:gem_name]
  raise "Unknown gem: #{gem}" unless REMOTE_GEMS.key?(gem)
  
  FileUtils.rm_rf "tmp/#{gem}"
  FileUtils.mkdir_p "tmp/#{gem}"
  sh "git clone --depth 1 #{REMOTE_GEMS[gem]} tmp/#{gem}"
end

desc "Pack a gem from a given path to public/"
task :pack_gem, [:gem_path] do |_, args|
  gem_path = args[:gem_path]

  sh "cd #{gem_path} && #{__dir__}/scripts/pack_gem"
  sh "cp #{gem_path}/tmp/#{File.basename(gem_path)}.pack.rb public/#{File.basename(gem_path)}.pack.rb"
end
