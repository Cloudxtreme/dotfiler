require 'setup/io'
require 'setup/logging'
require 'setup/reporter'

module Setup

# A context that contains a set of common options passed into tasks.
class SyncContext
  attr_reader :options

  def initialize(options = {})
    options[:io] ||= options[:dry] ? DRY_IO : CONCRETE_IO
    options[:sync_time] ||= Time.new
    options[:backup_dir] ||= ''
    options[:restore_dir] ||= ''
    options[:reporter] ||= Reporter.new
    options[:logger] ||= Logging.logger['Setup']
    @options = options
  end

  def [](key)
    @options[key]
  end

  def backup_path(relative_path = './')
    File.expand_path relative_path, @options[:backup_dir]
  end

  def restore_path(relative_path = './')
    File.expand_path relative_path, @options[:restore_dir]
  end

  def with_options(new_options)
    dup.tap { |sc| sc.options.merge!(new_options) }
  end

  def with_backup_dir(new_backup_dir)
    with_options backup_dir: backup_path(new_backup_dir)
  end

  def with_restore_dir(new_restore_dir)
    with_options restore_dir: restore_path(new_restore_dir)
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
end

end
