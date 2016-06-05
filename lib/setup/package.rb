require 'setup/file_sync'
require 'setup/file_sync_task'
require 'setup/io'
require 'setup/logging'
require 'setup/platform'

require 'pathname'

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
    File.expand_path relative_path, @options[:restore_root]
  end

  def with_options(new_options)
    SyncContext.new @options.merge new_options
  end

  def to_s
    @options.to_s
  end
end

# Represents a single task that copies multiple files.
# TODO(drognanar): Permit regular expressions in task config?
# TODO(drognanar): Just allow .rb files? Then they can do everything! Including calling regexps.
# TODO(drognanar): Covert sync items into SyncTask objects.
class Package
  attr_accessor :name, :should_execute, :io, :sync_items, :loaded_sync_items
  def initialize(config, host_info, io)
    @labels = host_info[:label] || []
    restore_root = Platform.get_config_value(config['root'], @labels) || ''
    platforms = config['platforms'] || []

    @io = io
    @name = config['name'] || ''
    @default_backup_root = host_info[:backup_root] || ''
    @default_backup_root = File.join @default_backup_root, @name
    @default_restore_root = host_info[:restore_root]
    @should_execute = Platform::has_matching_label @labels, platforms
    @loaded_sync_items = nil
    @sync_items = (config['files'] || [])
      .map { |file_config| resolve_sync_item file_config, restore_root, host_info }
      .compact
  end

  def load_context(ctx)
    @ctx = ctx.with_options backup_root: @default_backup_root, restore_root: @default_restore_root, io: @io
    @loaded_sync_items = @sync_items.map { |sync_item| sync_item.call() }
  end

  # Returns if this is a new package, i.e. none of its targets have been backed up.
  def new_package?
    info_by_status = @loaded_sync_items.map { |sync_item| sync_item.info }.group_by(&:status)
    info_by_status.keys.length == 1 && info_by_status.fetch(:backup, []).length > 0
  end

  # TODO(drognanar): Deprecate #has_data once #new_package is used for discovery.
  def has_data
    @loaded_sync_items.any? { |sync_item| sync_item.info.status.kind != :error }
  end

  def sync!
    @loaded_sync_items.each do |sync_item|
      yield sync_item
      begin
        sync_item.sync!
      rescue FileMissingError => e
        LOGGER.error e.message
      end
    end
  end

  # Returns the list of files that should be cleaned up in for this task.
  # This algorithm ensures to list only the top level folder to be cleaned up.
  # A file is not included if its parent is being backed up.
  # A file is not included if its parent is being cleaned up.
  def cleanup
    all_files = @io.glob(File.join(@default_backup_root, '**', '*')).sort
    backed_up_list = info.map(&:backup_path).sort
    files_to_cleanup = []

    # Because all files are sorted then:
    # If a file is being backed up it will be at the start of backed_up_list.
    # If a file's parent is being backed up it will be at the start of backed_up_list.
    # If a file's parent is being cleaned up it will be at the end of files_to_cleanup.
    all_files.each do |file|
      backed_up_list = backed_up_list.drop_while { |backed_up_file| backed_up_file < file and not file.start_with? backed_up_file }
      already_cleaned_up = (not files_to_cleanup.empty? and file.start_with? files_to_cleanup[-1])
      already_backed_up = (not backed_up_list.empty? and file.start_with? backed_up_list[0])
      should_clean_up = (File.basename(file).start_with?('setup-backup-') or @ctx[:untracked])

      if not already_cleaned_up and not already_backed_up and should_clean_up
        files_to_cleanup << file
      end
    end

    files_to_cleanup
  end

  def info
    @loaded_sync_items.map { |sync_item| sync_item.info }
  end

  private

  # This function replaces the first dot of a filename.
  # This makes all files visible on the backup.
  def self.escape_dotfile_path(restore_path)
    restore_path
      .split(File::Separator)
      .map { |part| part.sub(/^\./, '_') }
      .join(File::Separator)
  end

  # Resolve `file_config` into a `FileSyncStatus`.
  def resolve_sync_item(file_config, restore_root, host_info)
    resolved = resolve_sync_item_config(file_config, restore_root)
    if resolved
      proc do
        FileSyncTask.new resolved, @ctx
      end
    end
    # resolved ? [FileSync.new(host_info[:sync_time], @io), resolved] : nil
  end

  # Resolve `file_config` into `FileSyncStatus` configuration.
  def resolve_sync_item_config(file_config, restore_root)
    resolved = Platform.get_config_value(file_config, @labels)
    return nil if resolved.nil?

    if resolved.is_a? String
      resolved = { restore_path: resolved, backup_path: Package.escape_dotfile_path(resolved) }
    elsif resolved.is_a? Hash
      resolved = Hash[resolved.map { |k, v| [k.to_sym, v] }]
    end

    if resolved.fetch(:type, 'file') == 'file'
      resolved[:restore_path] = Platform.get_config_value(resolved[:restore_path], @labels)
      resolved[:backup_path] = Platform.get_config_value(resolved[:backup_path], @labels)
      resolved[:name] = resolved[:restore_path]
      resolved[:restore_path] = File.expand_path(Pathname(restore_root).join(resolved[:restore_path]), @default_restore_root)
      resolved[:backup_path] = File.expand_path(resolved[:backup_path], @default_backup_root)
    end

    resolved
  end
end

end
