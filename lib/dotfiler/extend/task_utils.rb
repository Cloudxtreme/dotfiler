require 'dotfiler/sync_utils'
require 'dotfiler/sync_context'
require 'dotfiler/tasks/file_sync_task'
require 'dotfiler/tasks/proc_task'
require 'dotfiler/tasks/task'

module Dotfiler
  # {TaskUtils} provides method helpers to generate tasks by classes that have
  # a +ctx+ method. The +ctx+ method should return a valid sync context. It also adds
  # these helpers into the following classes: {SyncContext}/{Tasks::Task}.
  #
  # @example Create a {Tasks::FileSyncTask} from a context
  #   SyncContext.new.file('.vimrc')
  # @example Create a {Tasks::ProcTask} from a package
  #   Package.new(SyncContext.new).run { puts 'running' }
  module TaskUtils
    # Error raised when loading a script file has caused an error,
    # thus packages from this file cannot be loaded.
    class ImportScriptError < StandardError
      attr_reader :path, :inner_exception

      def initialize(path, inner_exception)
        @path = path
        @inner_exception = inner_exception
      end
    end

    # @return [Tasks::FileSyncTask] a new {Tasks::FileSyncTask} with +path+ {SyncContext}.
    # @example
    #   file('.vimrc', copy: true)
    def file(path, file_sync_options = {})
      FileSyncTask.new(path, file_sync_options, ctx)
    end

    # @return [Tasks::ProcTask] a new {Tasks::ProcTask} that will execute a block when run.
    # @yieldparam ctx [SyncContext] context in which the code should run.
    # @example
    #   run { |ctx| ctx.file('.vimrc').sync! }
    def run(name = nil, &block)
      ProcTask.new(name, ctx, &block)
    end

    # @param app_name [String] name of the {Task} to find in {SyncContext}.
    # @return [Task] a task defined in {SyncContext#packages} with a corresponding name.
    # @example
    #   package('vim')
    def package(app_name)
      ctx.packages[app_name]
    end

    # @return [Task] a task with all {Tasks::Package}s with data to sync.
    def all_packages
      packages = ctx.packages.values.select(&:data?)
      ItemPackage.new(ctx).tap { |package| package.items = packages }
    end

    # @return [Task] a dynamically created task created by loading scripts under +packages_glob_rel+
    #   and finding all {Tasks::Package} instances.
    # @raise [ImportScriptError] when evaluating the script throws an exception.
    # @note if multiple {Tasks::Package} instances are found puts them into a {Tasks::ItemPackage}.
    # @note this method evaluates the files as ruby scripts. Thus files that match this glob pattern
    #   need to be trusted.
    # @example
    #   package_from_files('~/dotfiles/packages/*.rb')
    def package_from_files(packages_glob_rel)
      packages_glob = ctx.backup_path packages_glob_rel
      packages = get_packages(packages_glob, ctx)
      packages.length == 1 ? packages[0] : ItemPackage.new(ctx).tap { |package| package.items = packages }
    end

    private

    # Finds package definitions inside of a particular path.
    # @param package_path [string] Path to a script that contains package definitions.
    def find_package_cls(package_path, io)
      return [] unless File.extname(package_path) == '.rb'

      mod = Module.new
      package_script = io.read package_path

      begin
        mod.class_eval package_script, package_path, 1
      rescue Exception => e # rubocop:disable RescueException
        raise ImportScriptError.new package_path, e
      end

      # Iterate over all constants/classes defined by the script.
      # If a constant defines a package return it.
      mod.constants.sort
         .map(&mod.method(:const_get))
         .select { |const| !const.nil? && const < Package }
    end

    # Finds package definitions inside of a particular folder.
    # @param packages_glob [string] Glob for the script files that should contain packages.
    # @param ctx [SyncContext] {SyncContext} that should be passed into packages.
    def get_packages(packages_glob, ctx)
      (ctx.io.glob packages_glob)
        .map { |package_path| find_package_cls(package_path, ctx.io) }
        .flatten
        .map { |package_cls| package_cls.new ctx }
    end
  end

  # Add task helper methods into classes that contain context.

  class SyncContext
    include TaskUtils

    def add_default_applications
      add_packages_from_cls APPLICATIONS
    end

    def ctx
      self
    end
  end

  module Tasks
    class Task
      include TaskUtils
    end
  end
end
