require 'setup/file_sync'
require 'setup/io'
require 'setup/logging'
require 'setup/platform'

require 'pathname'

module Setup

# Represents a single task that copies multiple files.
# TODO(drognanar): Permit regular expressions in task config?
# TODO(drognanar): Just allow .rb files? Then they can do everything! Including calling regexps.
class Package
  attr_accessor :name, :should_execute, :io, :sync_items
  def initialize(config, host_info, io)
    @labels = host_info[:label] || []
    restore_root = Platform.get_config_value(config['root'], @labels) || ''
    @default_backup_root = host_info[:backup_root]
    @default_restore_root = host_info[:restore_root]
    platforms = config['platforms'] || []

    @io = io
    @name = config['name']
    @should_execute = Platform::has_matching_label @labels, platforms
    @sync_items = (config['files'] || [])
      .map { |file_config| resolve_sync_item file_config, restore_root, host_info }
      .flatten(1)
  end

  def has_data(options = {})
    @sync_items.any? { |sync_item, sync_options| sync_item.has_data sync_options.merge(options) }
  end

  def with_items(msg, options)
    @sync_items.each do |sync_item, sync_options|
      yield sync_options
      begin
        sync_item.send(msg, sync_options.merge(options))
      rescue FileMissingError => e
        LOGGER.error e.message
      end
    end
  end

  def sync!(options = {}, &block)
    with_items :sync!, options, &block
  end

  def backup!(options = {}, &block)
    with_items :backup!, options, &block
  end

  def restore!(options = {}, &block)
    with_items :restore!, options, &block
  end

  def reset!(options = {})
    @sync_items.each do |sync_item, sync_options|
      yield sync_options
      sync_item.reset! sync_options.merge(options)
    end
  end

  def backed_up_files
    @sync_items.map { |sync_item, sync_options| sync_item.info(sync_options).backup_path }
  end

  # Returns the list of files that should be cleaned up in for this task.
  # This algorithm ensures to list only the top level folder to be cleaned up.
  # A file is not included if its parent is being backed up.
  # A file is not included if its parent is being cleaned up.
  def cleanup(options = {})
    all_files = @io.glob(File.join(@default_backup_root, @name, '**', '*')).sort
    backed_up_list = backed_up_files.sort
    files_to_cleanup = []

    # Because all files are sorted then:
    # If a file is being backed up it will be at the start of backed_up_list.
    # If a file's parent is being backed up it will be at the start of backed_up_list.
    # If a file's parent is being cleaned up it will be at the end of files_to_cleanup.
    all_files.each do |file|
      backed_up_list = backed_up_list.drop_while { |backed_up_file| backed_up_file < file and not file.start_with? backed_up_file }
      already_cleaned_up = (not files_to_cleanup.empty? and file.start_with? files_to_cleanup[-1])
      already_backed_up = (not backed_up_list.empty? and file.start_with? backed_up_list[0])
      should_clean_up = (File.basename(file).start_with?('setup-backup-') or options[:untracked])

      if not already_cleaned_up and not already_backed_up and should_clean_up
        files_to_cleanup << file
      end
    end

    files_to_cleanup
  end

  def info(options = {}, action = :sync)
    @sync_items.map { |sync_item, sync_options| sync_item.info sync_options.merge(options), action }
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
    resolved ? [[FileSync.new(host_info[:sync_time], @io), resolved]] : []
  end

  # Resolve `file_config` into `FileSyncStatus` configuration.
  def resolve_sync_item_config(file_config, restore_root)
    resolved = Platform.get_config_value(file_config, @labels)
    return nil if resolved.nil?

    if resolved.is_a? String
      resolved = { restore_path: resolved, backup_path: Package.escape_dotfile_path(resolved) }
    end

    if resolved.fetch(:type, 'file') == 'file'
      resolved[:restore_path] = Platform.get_config_value(resolved[:restore_path], @labels)
      resolved[:backup_path] = Platform.get_config_value(resolved[:backup_path], @labels)
      resolved[:name] = resolved[:restore_path]
      resolved[:restore_path] = File.expand_path(Pathname(restore_root).join(resolved[:restore_path]), @default_restore_root)
      resolved[:backup_path] = File.expand_path(Pathname(@default_backup_root).join(@name, resolved[:backup_path]))
    end

    resolved
  end
end

end
