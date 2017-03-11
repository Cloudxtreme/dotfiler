require 'rake'
require 'rspec/core/rake_task'
require 'yard'

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
  nil # noop
end

task :rubocop do
  sh 'rubocop'
end

YARD::Rake::YardocTask.new

task :pry do
  require 'awesome_print'
  require 'dotfiler'
  require 'pry'
  include Dotfiler
  binding.pry # rubocop:disable Lint/Debugger
end

task default: [:spec, :yard, :rubocop]
