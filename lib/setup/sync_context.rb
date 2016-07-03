module Setup

class SyncContext
  def initialize(options = {})
    @options = options
  end

  def [](key)
    @options[key]
  end

  def backup_path(relative_path)
    File.expand_path relative_path, @options[:backup_root]
  end

  def restore_path(relative_path)
    File.expand_path relative_path, @options[:restore_to]
  end

  def with_options(new_options)
    SyncContext.new @options.merge new_options
  end
end

end