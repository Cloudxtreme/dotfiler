require 'setup/file_sync'

module Setup

class FileSyncTask
  attr_reader :name, :file_sync_options

  def initialize(name, file_sync_options, ctx)
    @name = name
    @file_sync_options = file_sync_options
    @ctx = ctx
  end

  def self.create(filepath, file_sync_options, ctx)
    file_sync_options = FileSyncTask.get_file_sync_options(filepath, file_sync_options, ctx)
    file_sync_options[:copy] = ctx[:copy] if ctx[:copy]
    file_sync_options[:on_overwrite] = ctx[:on_overwrite] if ctx[:on_overwrite]
    FileSyncTask.new file_sync_options[:name], file_sync_options, ctx
  end

  def self.get_file_sync_options(filepath, options, ctx)
    options.merge({
      name: filepath,
      restore_path: ctx.restore_path(filepath),
      backup_path: FileSyncTask.escape_dotfile_path(ctx.backup_path filepath) })
  end

  # This function replaces the first dot of a filename.
  # This makes all files visible on the backup.
  def self.escape_dotfile_path(restore_path)
    restore_path
      .split(File::Separator)
      .map { |part| part.sub(/^\./, '_') }
      .join(File::Separator)
  end

  # TODO(drognanar): Create an object copy?
  def save_as(backup_path)
    self.tap { @file_sync_options[:backup_path] = @ctx.backup_path backup_path }
  end

  def sync!
    FileSync.new(@ctx[:sync_time], @ctx[:io]).sync! @file_sync_options
  end

  def info
    FileSync.new(@ctx[:sync_time], @ctx[:io]).info @file_sync_options
  end
end

end
