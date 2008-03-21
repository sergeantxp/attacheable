require 'test/unit'
require 'rubygems'
require 'active_support'
require 'active_record'
require 'action_pack'
require 'attacheable'


$:.unshift File.join(File.dirname(__FILE__), '../lib')

RAILS_ROOT.replace(File.dirname(__FILE__))
