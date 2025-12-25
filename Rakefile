# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "rb_sys/extensiontask"

GEMSPEC = Gem::Specification.load("udon.gemspec")

RbSys::ExtensionTask.new("udon", GEMSPEC) do |ext|
  ext.lib_dir = "lib/udon"
end

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

task default: %i[compile test]

desc "Run benchmarks"
task :bench do
  ruby "test/benchmark.rb"
end
