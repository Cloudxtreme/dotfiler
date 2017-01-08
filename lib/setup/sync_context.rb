require 'setup/io'
require 'setup/reporter'

module Setup

# A context that contains a set of common options passed into tasks.
class SyncContext
  attr_reader :options

  def [](key)
    @options[key]
  end

  def backup_path(relative_path = './')
    File.expand_path relative_path, @options[:backup_root]
  end

  def restore_path(relative_path = './')
    File.expand_path relative_path, @options[:restore_to]
  end

  def with_options(new_options)
    dup.tap { |sc| sc.options.merge!(new_options) }
  end

  def with_backup_root(new_backup_root)
    dup.tap { |sc| sc.options[:backup_root] = backup_path(new_backup_root) }
  end

  def with_restore_to(new_restore_to)
    dup.tap { |sc| sc.options[:restore_to] = restore_path(new_restore_to) } 
  end

  def dup
    SyncContext.new @options.dup
  end

  def io
    @options[:io]
  end

  def reporter
    @options[:reporter]
  end

  def logger
    @options[:logger]
  end

  def initialize(options = {})
    options[:io] ||= options[:dry] ? DRY_IO : CONCRETE_IO
    options[:sync_time] ||= Time.new
    options[:backup_root] ||= ''
    options[:restore_to] ||= ''
    options[:reporter] ||= Reporter.new
    options[:logger] ||= Logging.logger['Setup']
    @options = options
  end
end

end
