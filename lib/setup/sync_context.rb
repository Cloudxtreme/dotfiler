require 'setup/io'

module Setup

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
    SyncContext.new @options.merge(new_options)
  end

  def with_backup_root(new_backup_root)
    SyncContext.new @options.merge(backup_root: backup_path(new_backup_root))
  end

  def with_restore_to(new_restore_to)
    SyncContext.new @options.merge(restore_to: restore_path(new_restore_to))
  end

  def io
    @options[:io]
  end

  def initialize(options = {})
    options[:io] ||= options[:dry] ? DRY_IO : CONCRETE_IO
    options[:sync_time] ||= Time.new
    options[:backup_root] ||= ''
    options[:restore_to] ||= ''
    @options = options
  end
end

end
