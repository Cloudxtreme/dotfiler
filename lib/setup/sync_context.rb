require 'setup/io'

module Setup

class SyncContext
  attr_reader :backup_root, :restore_to, :io

  def self.create(io = nil, options = {})
    io ||= CONCRETE_IO
    options[:sync_time] = Time.new
    SyncContext.new io, '', '', options
  end

  def [](key)
    @options[key]
  end

  def backup_path(relative_path)
    File.expand_path relative_path, @backup_root
  end

  def restore_path(relative_path)
    File.expand_path relative_path, @restore_to
  end

  def with_options(new_options)
    SyncContext.new @io, @backup_root, @restore_to, @options.merge(new_options)
  end

  def with_backup_root(new_backup_root)
    SyncContext.new @io, new_backup_root, @restore_to, @options
  end

  def with_restore_to(new_restore_to)
    SyncContext.new @io, @backup_root, new_restore_to, @options
  end

  private

  def initialize(io, backup_root, restore_to, options = {})
    @io = io
    @backup_root = backup_root
    @restore_to = restore_to
    @options = options
  end
end

end
