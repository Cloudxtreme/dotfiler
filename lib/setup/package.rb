require 'setup/file_sync'
require 'setup/file_sync_task'
require 'setup/io'
require 'setup/logging'
require 'setup/platform'

require 'forwardable'
require 'json'
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

# Make it easy to subclass PackageBase as well for a single Package.
class PackageBase
  extend Forwardable

  attr_accessor :io, :sync_items
  attr_reader :should_execute, :skip_message

  def self.name(value)
    self.class_eval "def name; #{JSON.dump(value)}; end"
  end

  def self.config_dir(value)
    self.class_eval "def config_dir; #{JSON.dump(value)}; end"
  end

  def self.under_windows(&block)
    block.call if Platform::windows?
  end

  def self.under_macos(&block)
    block.call if Platform::macos?
  end

  def self.under_linux(&block)
    block.call if Platform::linux?
  end

  def_delegators PackageBase, :under_windows?, :under_macos?, :under_linux?

  def steps
  end

  name ''
  config_dir ''

  # TODO(drognanar): Should work under the class as well.
  def skip(msg)
    @should_execute = false
    @skip_message = msg
  end

  def platforms(platforms)
    unless Platform::has_matching_label @labels, platforms
      skip 'Unsupported platform'
    end
  end

  # TODO: get rid of @labels.
  def initialize(ctx, io)
    @sync_items = []
    @default_backup_root = ctx[:backup_root] || ''
    @default_backup_root = File.join @default_backup_root, name
    @default_restore_root = ctx[:restore_root]
    @should_execute = true
    @io = io
    @labels = ctx[:label] || []

    @ctx = ctx.with_options backup_root: @default_backup_root, restore_root: @default_restore_root, io: @io
  end

  def file(filepath)

  end

  # TODO(drognanar): Deprecate #has_data once #new_package is used for discovery?
  # TODO(drognanar): Determine if this claim is still valid.
  def has_data
    @sync_items.any? { |sync_item| sync_item.info.status.kind != :error }
  end

  def sync!
    @sync_items.each do |sync_item|
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
  # NOTE: Given that list of backed up paths is platform specific this solution will not work.
  # NOTE: Unless all paths are provided. 
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
    @sync_items.map { |sync_item| sync_item.info }
  end

end

# Represents a package generated from a yaml configuration file.
# TODO(drognanar): Permit regular expressions in task config?
# TODO(drognanar): Just allow .rb files? Then they can do everything! Including calling regexps.
# TODO(drognanar): Start loading .rb file packages.
# TODO(drognanar): Covert sync items into SyncTask objects.
class Package < PackageBase
  attr_accessor :name

  def initialize(config, ctx, io)
    @name = config['name'] || ''
    @config = config
    super ctx, io
    platforms (config['platforms'] || [])

    steps
  end

  def steps
    restore_root = Platform.get_config_value(@config['root'], @labels) || ''
    @sync_items = (@config['files'] || [])
      .map { |file_config| resolve_sync_item file_config, restore_root, @ctx }
      .compact
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
      FileSyncTask.new(resolved, @ctx)
    end
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

    resolved[:restore_path] = Platform.get_config_value(resolved[:restore_path], @labels)
    resolved[:backup_path] = Platform.get_config_value(resolved[:backup_path], @labels)
    resolved[:name] = resolved[:restore_path]
    resolved[:restore_path] = File.expand_path(Pathname(restore_root).join(resolved[:restore_path]), @default_restore_root)
    resolved[:backup_path] = File.expand_path(resolved[:backup_path], @default_backup_root)

    resolved
  end
end

end
