require 'test/unit'
require 'rubygems'
require 'active_support'
require 'active_record'
require 'action_pack'
$KCODE = 'u'

$:.unshift File.join(File.dirname(__FILE__), '../lib')
if defined?(RAILS_ROOT)
  RAILS_ROOT.replace(File.dirname(__FILE__))
else
  RAILS_ROOT = File.dirname(__FILE__) 
end
require 'attacheable'


