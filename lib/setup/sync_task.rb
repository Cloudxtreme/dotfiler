require 'setup/file_sync'
require 'setup/platforms'
require 'setup/io'

require 'pathname'

module Setup

# Represents a single task that copies multiple files.
# TODO: resolve multiple files being deployed.
# TODO: rename the classes (SyncTask/Backup)
class SyncTask
  attr_accessor :name, :should_execute, :io, :platforms

  def initialize(config, host_info = nil, io = nil)
    raise 'Expected io to be non nil' if io.nil?
    host_info ||= {}
    label = host_info[:label]
    restore_root = Setup::Config.get_config_value(config['root'], label) || ''
    @platforms = config['platforms'] || []

    @io = io
    @name = config['name']
    @should_execute = Config::has_matching_label label, @platforms
    @sync_items = (config['files'] || [])
      .map { |file_config| SyncTask.resolve_sync_item file_config, restore_root, @name, host_info, io }
      .compact
  end

  def has_data(options = nil)
    @sync_items.any? { |sync_item| sync_item.has_data options }
  end

  def backup!(options = nil)
    @sync_items.each { |sync_item| sync_item.backup! options }
  end

  def restore!(options = nil)
    @sync_items.each { |sync_item| sync_item.restore! options }
  end

  def reset!
    @sync_items.each(&:reset!)
  end

  def cleanup
    @sync_items.map(&:cleanup)
  end

  def info
    @sync_items.map(&:info)
  end

  def SyncTask.escape_dotfile_path(restore_path)
    restore_path
      .split(File::Separator)
      .map { |part| part.sub(/^\./, '_') }
      .join(File::Separator)
  end

  private

  # Resolve `file_config` into a `FileSyncStatus`.
  def SyncTask.resolve_sync_item(file_config, restore_root, name, host_info, io = IO)
    resolved = resolve_sync_item_config(file_config, restore_root, name, host_info)
    resolved ? FileSync.new(resolved, host_info[:sync_time], io) : nil
  end

  # Resolve `file_config` into `FileSyncStatus` configuration.
  def SyncTask.resolve_sync_item_config(file_config, restore_root, name, host_info)
    label = host_info[:label]
    default_restore_root = host_info[:restore_root]
    default_backup_root = host_info[:backup_root]

    resolved = Setup::Config.get_config_value(file_config, label)
    if resolved.is_a? String
      restore_path = File.expand_path(Pathname(restore_root).join(resolved), default_restore_root)
      backup_path = File.expand_path(Pathname(default_backup_root).join(name, escape_dotfile_path(resolved)))
      {restore_path: restore_path, backup_path: backup_path}
    else
      # TODO: do we not need to expand paths here as well?
      # TODO: just resolve the conversion type.
      # TODO: are keys strings?
      resolved
    end
  end
end

end
