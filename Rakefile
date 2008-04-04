require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rake/gempackagetask'

spec = Gem::Specification.new do |s|
  s.name = 'attacheable'
  s.version = '1.0'
  s.summary = 'Library to handle image uploads'
  s.autorequire = 'attacheable'
  s.author  = "Max Lapshin"
  s.email   = "max@maxidoors.ru"
  s.description = "Fork of attachment_fu. It differs in following ways:



  1. Can work with merb uploads

  2. can create thumbnails on fly

  3. goes with Mongrel handler, that autocreate thumbnails on demand

  4. works only with file system (and does it better, than attachment_fu)

  5. create only one row in table for one image. No separate rows for each thumbnail."
  
end

Rake::GemPackageTask.new(spec) do |package|
  package.gem_spec = spec
end


task :default => [ :test ]

desc "Run all tests (requires BlueCloth, RedCloth and Rails for integration tests)"
Rake::TestTask.new("test") { |t|
  t.libs << "test"
  t.pattern = 'test/*_test.rb'
  t.verbose = true
}
