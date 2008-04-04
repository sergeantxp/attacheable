require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rake/gempackagetask'

spec = Gem::Specification.new do |s|
  s.name = 'attacheable'
  s.version = '1.0'
  s.summary = 'Library to handle image uploads'
  s.autorequire = 'attacheable'
end

task :default => [ :test ]

desc "Run all tests (requires BlueCloth, RedCloth and Rails for integration tests)"
Rake::TestTask.new("test") { |t|
  t.libs << "test"
  t.pattern = 'test/*_test.rb'
  t.verbose = true
}
