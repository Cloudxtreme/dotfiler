require 'setup/file_sync_task'
require 'setup/platform'
require 'setup/task'

require 'json'

module Setup

# A package is a collection Tasks.
class Package < Task
  include Enumerable

  DEFAULT_RESTORE_TO = File.expand_path '~/'

  def self.restore_to(value)
    self.class_eval "def restore_to; #{JSON.dump(File.expand_path(value, '~/')) if value}; end"
  end

  def self.package_name(value)
    self.class_eval "def name; #{JSON.dump(value) if value}; end"
  end

  def self.platforms(platforms)
    self.class_eval "def platforms; #{platforms if platforms}; end"
  end

  package_name ''

  def description
    "package #{name}"
  end

  def each
    steps { |step| yield step }
  end

  def steps
  end

  def children?
    true
  end

  def initialize(parent_ctx)
    ctx = parent_ctx
      .with_backup_root(File.join(parent_ctx.backup_path, name))
      .with_restore_to(defined?(restore_to) ? restore_to : Package::DEFAULT_RESTORE_TO)
    super(ctx)

    if defined?(platforms) and (not platforms.empty?) and (not platforms.include? Platform.get_platform)
      skip 'Unsupported platform'
    end
  end

  def has_data
    any? { |sync_item| sync_item.info.status.kind != :error }
  end

  def sync!
    return unless should_execute
    execute(:sync) { each { |sync_item| sync_item.sync! } }
  end

  # TODO(drognanar): Deprecate? Given the platform specific nature of packages.
  # TODO(drognanar): Use the file_sync_task to remove stray files.
  # Returns the list of files that should be cleaned up in for this task.
  # This algorithm ensures to list only the top level folder to be cleaned up.
  # A file is not included if its parent is being backed up.
  # A file is not included if its parent is being cleaned up.
  # NOTE: Given that list of backed up paths is platform specific this solution will not work.
  # NOTE: Unless all paths are provided.
  def cleanup
    return [] unless should_execute
    all_files = @ctx.io.glob(File.join(@ctx.backup_path, '**', '*')).sort
    backed_up_list = map(&:backup_path).sort
    files_to_cleanup = []

    # Because all files are sorted then:
    # If a file is being backed up it will be at the start of backed_up_list.
    # If a file's parent is being backed up it will be at the start of backed_up_list.
    # If a file's parent is being cleaned up it will be at the end of files_to_cleanup.
    all_files.each do |file|
      backed_up_list = backed_up_list.drop_while { |backed_up_file| backed_up_file < file and not file.start_with? backed_up_file }
      already_cleaned_up = (not files_to_cleanup.empty? and file.start_with? files_to_cleanup[-1])
      already_backed_up = (not backed_up_list.empty? and file.start_with? backed_up_list[0])
      should_clean_up = File.basename(file).start_with?('setup-backup-')

      if not already_cleaned_up and not already_backed_up and should_clean_up
        files_to_cleanup << file
        confirm_delete = @ctx[:on_delete].call(file)
        @ctx.io.rm_rf file if confirm_delete
      end
    end

    files_to_cleanup
  end
end

class ItemPackage < Package
  attr_accessor :items

  def initialize(ctx)
    super(ctx)
    @items = []
  end

  def steps
    items.each { |item| yield item }
  end
end

end # module Setup
