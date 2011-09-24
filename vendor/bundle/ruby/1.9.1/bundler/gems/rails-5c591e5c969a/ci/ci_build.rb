#!/usr/bin/env ruby
require 'fileutils'
include FileUtils

def root_dir
  @root_dir ||= File.expand_path('../..', __FILE__)
end

def rake(*tasks)
  tasks.each do |task|
    cmd = "bundle exec rake #{task}"
    puts "Running command: #{cmd}"
    return false unless system(cmd)
  end
  true
end

puts "[CruiseControl] Rails build"
build_results = {}

# Install required version of bundler.
bundler_install_cmd = "sudo gem install bundler --no-ri --no-rdoc"
puts "Running command: #{bundler_install_cmd}"
build_results[:install_bundler] = system bundler_install_cmd

cd root_dir do
  puts
  puts "[CruiseControl] Bundling gems"
  puts
  build_results[:bundle] = system 'bundle update'
end

cd "#{root_dir}/activesupport" do
  puts
  puts "[CruiseControl] Building Active Support"
  puts
  build_results[:activesupport] = rake 'test'
  build_results[:activesupport_isolated] = rake 'test:isolated'
end

system "sudo rm -R #{root_dir}/railties/tmp"
cd "#{root_dir}/railties" do
  puts
  puts "[CruiseControl] Building Railties"
  puts
  build_results[:railties] = rake 'test'
end

cd "#{root_dir}/actionpack" do
  puts
  puts "[CruiseControl] Building Action Pack"
  puts
  build_results[:actionpack] = rake 'test'
  build_results[:actionpack_isolated] = rake 'test:isolated'
end

cd "#{root_dir}/actionmailer" do
  puts
  puts "[CruiseControl] Building Action Mailer"
  puts
  build_results[:actionmailer] = rake 'test'
  build_results[:actionmailer_isolated] = rake 'test:isolated'
end

cd "#{root_dir}/activemodel" do
  puts
  puts "[CruiseControl] Building Active Model"
  puts
  build_results[:activemodel] = rake 'test'
  build_results[:activemodel_isolated] = rake 'test:isolated'
end

rm_f "#{root_dir}/activeresource/debug.log"
cd "#{root_dir}/activeresource" do
  puts
  puts "[CruiseControl] Building Active Resource"
  puts
  build_results[:activeresource] = rake 'test'
  build_results[:activeresource_isolated] = rake 'test:isolated'
end

rm_f "#{root_dir}/activerecord/debug.log"
cd "#{root_dir}/activerecord" do
  puts
  puts "[CruiseControl] Building Active Record with MySQL IM enabled"
  puts
  ENV['IM'] = 'true'
  build_results[:activerecord_mysql_IM] = rake 'mysql:rebuild_databases', 'mysql:test'
  build_results[:activerecord_mysql_isolated_IM] = rake 'mysql:rebuild_databases', 'mysql:isolated_test'
end

cd "#{root_dir}/activerecord" do
  puts
  puts "[CruiseControl] Building Active Record with MySQL IM disabled"
  puts
  ENV['IM'] = 'false'
  build_results[:activerecord_mysql] = rake 'mysql:rebuild_databases', 'mysql:test'
  build_results[:activerecord_mysql_isolated] = rake 'mysql:rebuild_databases', 'mysql:isolated_test'
end

cd "#{root_dir}/activerecord" do
  puts
  puts "[CruiseControl] Building Active Record with MySQL2 IM enabled"
  puts
  ENV['IM'] = 'true'
  build_results[:activerecord_mysql2_IM] = rake 'mysql:rebuild_databases', 'mysql2:test'
  build_results[:activerecord_mysql2_isolated_IM] = rake 'mysql:rebuild_databases', 'mysql2:isolated_test'
end

cd "#{root_dir}/activerecord" do
  puts
  puts "[CruiseControl] Building Active Record with MySQL2 IM disabled"
  puts
  ENV['IM'] = 'false'
  build_results[:activerecord_mysql2] = rake 'mysql:rebuild_databases', 'mysql2:test'
  build_results[:activerecord_mysql2_isolated] = rake 'mysql:rebuild_databases', 'mysql2:isolated_test'
end

cd "#{root_dir}/activerecord" do
  puts
  puts "[CruiseControl] Building Active Record with PostgreSQL IM enabled"
  puts
  ENV['IM'] = 'true'
  build_results[:activerecord_postgresql8_IM] = rake 'postgresql:rebuild_databases', 'postgresql:test'
  build_results[:activerecord_postgresql8_isolated_IM] = rake 'postgresql:rebuild_databases', 'postgresql:isolated_test'
end

cd "#{root_dir}/activerecord" do
  puts
  puts "[CruiseControl] Building Active Record with PostgreSQL IM disabled"
  puts
  ENV['IM'] = 'false'
  build_results[:activerecord_postgresql8] = rake 'postgresql:rebuild_databases', 'postgresql:test'
  build_results[:activerecord_postgresql8_isolated] = rake 'postgresql:rebuild_databases', 'postgresql:isolated_test'
end

cd "#{root_dir}/activerecord" do
  puts
  puts "[CruiseControl] Building Active Record with SQLite 3 IM enabled"
  puts
  ENV['IM'] = 'true'
  build_results[:activerecord_sqlite3_IM] = rake 'sqlite3:test'
  build_results[:activerecord_sqlite3_isolated_IM] = rake 'sqlite3:isolated_test'
end

cd "#{root_dir}/activerecord" do
  puts
  puts "[CruiseControl] Building Active Record with SQLite 3 IM disabled"
  puts
  ENV['IM'] = 'false'
  build_results[:activerecord_sqlite3] = rake 'sqlite3:test'
  build_results[:activerecord_sqlite3_isolated] = rake 'sqlite3:isolated_test'
end


puts
puts "[CruiseControl] Build environment:"
puts "[CruiseControl]   #{`cat /etc/issue`}"
puts "[CruiseControl]   #{`uname -a`}"
puts "[CruiseControl]   #{`ruby -v`}"
puts "[CruiseControl]   #{`mysql --version`}"
puts "[CruiseControl]   #{`pg_config --version`}"
puts "[CruiseControl]   SQLite3: #{`sqlite3 -version`}"
`gem env`.each_line {|line| print "[CruiseControl]   #{line}"}
puts "[CruiseControl]   Bundled gems:"
`bundle show`.each_line {|line| print "[CruiseControl]     #{line}"}
puts "[CruiseControl]   Local gems:"
`gem list`.each_line {|line| print "[CruiseControl]     #{line}"}

failures = build_results.select { |key, value| value == false }

if failures.empty?
  puts
  puts "[CruiseControl] Rails build finished sucessfully"
  exit(0)
else
  puts
  puts "[CruiseControl] Rails build FAILED"
  puts "[CruiseControl] Failed components: #{failures.map { |component| component.first }.join(', ')}"
  exit(-1)
end
