# Setup::Tasks provides method helpers to generate tasks by classes that have
# a ctx method. The ctx method should return a valid sync context. It also adds
# these helpers into the following classes: SyncContext/Task.
require 'setup/backups'
require 'setup/file_sync_task'
require 'setup/sync_context'
require 'setup/task'

module Setup
  class InvalidConfigFileError < StandardError
    attr_reader :path, :inner_exception

    def initialize(path, inner_exception)
      @path = path
      @inner_exception = inner_exception
    end
  end

  module Tasks
    # Returns a new FileSyncTask with the expected context.
    def file(path, file_sync_options = {})
      FileSyncTask.new(path, file_sync_options, ctx)
    end

    # Returns a package with a given name within the context.
    def package(app_name)
      ctx.packages[app_name]
    end

    def package_from_files(packages_glob_rel)
      packages_glob = ctx.backup_path packages_glob_rel
      packages = get_packages(packages_glob, ctx)
      packages.length == 1 ? packages[0] : ItemPackage.new(ctx).tap { |package| package.items = packages }
    end

    private

    # Finds package definitions inside of a particular path.
    # @param string package_path Path to a script that contains package definitions.
    def find_package_cls(package_path, io)
      return [] unless File.extname(package_path) == '.rb'

      mod = Module.new
      package_script = io.read package_path

      begin
        mod.class_eval package_script, package_path, 1
      rescue Exception => e
        raise InvalidConfigFileError.new package_path, e
      end

      # Iterate over all constants/classes defined by the script.
      # If a constant defines a package return it.
      mod.constants.sort
         .map(&mod.method(:const_get))
         .select { |const| !const.nil? && const < Package }
    end

    # Finds package definitions inside of a particular folder.
    # @param string packages_glob Glob for the script files that should contain packages.
    # @param SyncContext ctx Context that should be passed into packages.
    def get_packages(packages_glob, ctx)
      (ctx.io.glob packages_glob)
        .map { |package_path| find_package_cls(package_path, ctx.io) }
        .flatten
        .map { |package_cls| package_cls.new ctx }
    end
  end # module Tasks

  # Add task helper methods into classes that contain context.

  class SyncContext
    include Tasks

    def add_default_applications
      add_packages_from_cls APPLICATIONS
    end

    def ctx
      self
    end
  end

  class Task
    include Tasks
  end
end # module Setup
