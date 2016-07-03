require 'setup/io'

module Setup

class SyncContext
  def self.create(io = nil, options = {})
    io ||= CONCRETE_IO
    options[:sync_time] = Time.new
    SyncContext.new io, options
  end

  def [](key)
    @options[key]
  end

  def io
    @io
  end

  def backup_path(relative_path)
    File.expand_path relative_path, @options[:backup_root]
  end

  def restore_path(relative_path)
    File.expand_path relative_path, @options[:restore_to]
  end

  def with_options(new_options)
    SyncContext.new @io, @options.merge(new_options)
  end

  private

  def initialize(io, options = {})
    @io = io
    @options = options
  end
end

end
