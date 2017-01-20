require 'setup/task'

require 'json'

module Setup
  # A {Package} is a {Task} that is defined as a collection of subtasks.
  # The subtasks are defined the {#steps} command which yield all subtasks to execute.
  #
  # @example
  #   class SetupPackage < Setup::Package
  #     package_name 'setup'
  #     under_windows { restore_dir '~/AppData/Local' }
  #     under_linux   { restore_dir '~/.config' }
  #     platforms [:windows, :linux]
  #
  #     def steps
  #       yield FileSyncTask.new(ctx)
  #     end 
  #   end
  #   SetupPackage.new(SyncContext.new).sync! # Will call sync! on FileSyncTask if running windows or linux.
  class Package < Task
    include Enumerable

    DEFAULT_RESTORE_DIR = File.expand_path '~/'

    # A helper method that allows to define the directory to which a given package
    # should restore its data (relative to {SyncContext}).
    def self.restore_dir(value)
      class_eval "def restore_dir; #{JSON.dump(File.expand_path(value, '~/')) if value}; end"
    end

    # A helper method that allows to define the directory to define the name of a package.
    # @note if a name is defined the files will be backed up to a subdirectory with +value+.
    def self.package_name(value)
      class_eval "def name; #{JSON.dump(value) if value}; end"
    end

    # A helper method that allows to define the list of platforms that a {Package} supports
    # within the {Package} definition.
    def self.platforms(platforms)
      class_eval "def platforms; #{platforms if platforms}; end"
    end

    package_name ''

    # (see Task#description)
    def description
      "package #{name}" unless name.empty?
    end

    # @yieldparam subtask [Task] subtasks of this {Package}.
    def each
      steps { |step| yield step }
    end

    # @yieldparam subtask [Task] subtasks of this {Package}.
    def steps; end

    def initialize(parent_ctx)
      ctx = parent_ctx.with_backup_dir(File.join(parent_ctx.backup_path, name))
                      .with_restore_dir(defined?(restore_dir) ? restore_dir : Package::DEFAULT_RESTORE_DIR)
      super(ctx)

      skip 'Unsupported platform' if defined?(platforms) && !platforms.empty? && (!platforms.include? Platform.get_platform)
    end

    # (see Task#status)
    def status
      status_items = select(&:should_execute).map(&:status)
      GroupStatus.new name, status_items
    end

    # (see Task#sync!)
    def sync!
      execute(:sync) { each(&:sync!) }
    end

    # (see Task#cleanup!)
    def cleanup!
      execute(:clean) { each(&:cleanup!) }
    end
  end

  # An {ItemPackage} is a {Package} that is defined as a collection of subtasks.
  # It contains a field {#items} and instead of having to yield subtasks these can be appended to the items list.
  #
  # @example
  #   ctx = SyncContext.new
  #   package = ItemPackage.new ctx
  #   package.items << FileSyncTask.new(ctx)
  #   package.sync! # Will call sync! on FileSyncTask.
  class ItemPackage < Package
    attr_accessor :items

    def initialize(ctx)
      super(ctx)
      @items = []
    end

    # (see Package#steps)
    def steps
      items.each { |item| yield item }
    end
  end
end # module Setup
