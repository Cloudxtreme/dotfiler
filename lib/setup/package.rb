require 'setup/file_sync_task'
require 'setup/logging'
require 'setup/platform'
require 'setup/sync_context'

require 'forwardable'
require 'json'
require 'pathname'

module Setup

class Package
  extend Forwardable

  DEFAULT_RESTORE_TO = File.expand_path '~/'

  attr_accessor :sync_items, :skip_reason

  def self.restore_to(value)
    self.class_eval "def restore_to; #{JSON.dump(File.expand_path(value, '~/')) if value}; end"
  end

  def self.name(value)
    self.class_eval "def name; #{JSON.dump(value) if value}; end"
  end

  def self.platforms(platforms)
    self.class_eval "def platforms; #{platforms if platforms}; end"
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

  def_delegators Package, :under_windows, :under_macos, :under_linux

  def skip(reason)
    @skip_reason = reason
  end

  name ''
  restore_to nil
  platforms []

  def steps
  end

  def should_execute
    return @skip_reason.nil?
  end

  def initialize(ctx)
    @sync_items = []
    @skip_reason = nil

    @default_backup_root = ctx[:backup_root] || ''
    @default_backup_root = File.join @default_backup_root, name
    @default_restore_to = restore_to || Package::DEFAULT_RESTORE_TO

    @ctx = ctx.with_options backup_root: @default_backup_root, restore_to: @default_restore_to

    unless platforms.empty? or platforms.include? Platform.get_platform
      skip 'Unsupported platform'
    end

    steps
  end

  # Adds a new file sync task.
  def file(filepath, options = {})
    FileSyncTask.create(filepath, options, @ctx).tap { |task| @sync_items << task }
  end

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
    all_files = @ctx.io.glob(File.join(@default_backup_root, '**', '*')).sort
    backed_up_list = @sync_items.map(&:backup_path).sort
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
end

end # module Setup
