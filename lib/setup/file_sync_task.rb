require 'setup/file_sync'
require 'setup/task'

module Setup

class FileSyncTask < Task
  attr_reader :name
  alias_method :description, :name

  def initialize(name, file_sync_options, ctx)
    super(ctx)
    @name = name
    @file_sync_options = { restore_path: name }.merge file_sync_options
  end

  def file_sync_options
    options = @file_sync_options.dup
    options[:restore_path] = ctx.restore_path options[:restore_path]
    options[:backup_path] = ctx.backup_path (options[:backup_path] || FileSyncTask.escape_dotfile_path(File.basename(options[:restore_path])))
    options[:copy] ||= ctx.options[:copy] if ctx.options[:copy]
    options[:on_overwrite] ||= ctx.options[:on_overwrite] if ctx.options[:on_overwrite]
    options
  end

  # This function replaces the first dot of a filename.
  # This makes all files visible on the backup.
  def self.escape_dotfile_path(restore_path)
    restore_path
      .split(File::Separator)
      .map { |part| part.sub(/^\./, '_') }
      .join(File::Separator)
  end

  def backup_path
    file_sync_options[:backup_path]
  end

  def save_as(new_backup_path)
    self.tap { @file_sync_options[:backup_path] = new_backup_path }
  end

  def sync!
    execute(:sync) { FileSync.new(ctx.options[:sync_time], io).sync! file_sync_options }
  rescue FileSyncError => e
    logger.error e.message
  end

  def cleanup!
    execute(:clean) do
      backup_prefix = @file_sync_options[:backup_prefix] || DEFAULT_FILESYNC_OPTIONS[:backup_prefix]
      backup_file_name = File.basename backup_path
      backup_files_glob = ctx.backup_path "#{backup_prefix}-*-#{backup_file_name}"
      io.glob(backup_files_glob).each do |file|
        if ctx.options[:on_delete].call(file)
          execute(:delete) { io.rm_rf file }
        end
      end
    end
  end

  def info
    FileSync.new(ctx.options[:sync_time], io).info file_sync_options
  end

  def status
    FileSync.new(ctx.options[:sync_time], io).info(file_sync_options).status
  end
end

end
