require 'rubygems'
require 'rspec'

Dir.entries(File.dirname(__FILE__) + "/../lib").each do |file|
  require File.dirname(__FILE__) + "/../lib/#{file}" if file =~ /.rb$/
end
