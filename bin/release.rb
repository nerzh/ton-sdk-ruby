#!/usr/bin/env ruby

script_file_path = File.expand_path(File.dirname(__FILE__))
GEM_DIR = "#{script_file_path}/.."

version_file = "#{GEM_DIR}/lib/ton-sdk-ruby/version.rb"
file = File.read(version_file)

p 'check version'
if file[/VERSION = "(\d+)\.(\d+)\.(\d+)"/]
  major = $1
  minor = $2
  current = $3
  version = "#{major}.#{minor}.#{current.to_i + 1}"
  p version
  data = "module TonClient\n  VERSION = \"#{version}\"\nend\n\n"
  p data
  p version_file
  File.open(version_file, 'wb') { |f| f.write(data) }
  p 'update version'

  puts "make release? Y/N"
  option = gets
  if option.strip.downcase == 'y'
    system(%{cd #{GEM_DIR} && git add .})
    system(%{cd #{GEM_DIR} && git commit -m 'version #{version}'})
    system(%{cd #{GEM_DIR} && bash -lc 'rake release'})
  end
end

