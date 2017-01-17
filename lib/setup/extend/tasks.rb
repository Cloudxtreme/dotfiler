# Setup::Tasks provides method helpers to generate tasks by classes that have
# a ctx method. The ctx method should return a valid sync context. It also adds
# these helpers into the following classes: SyncContext/Package/Backup/
# BackupManager.
require 'setup/backups'
require 'setup/file_sync_task'
require 'setup/package'
require 'setup/sync_context'

module Setup
module Tasks

# Returns a new FileSyncTask with the expected context.
def file(path, file_sync_options = {})
  FileSyncTask.new(path, file_sync_options, ctx)
end

# Returns a package with a given name within the context.
def package(app_name)
  ctx.packages[app_name]
end

def backup(backup_dir)
  yield if block_given? and not ctx.io.exist? backup_dir

  # TODO: Deal with the case where the backup_dir is still missing.
  # TODO: Allow to provide a backup.rb file.
  backup_ctx = ctx.with_backup_dir(backup_dir).add_default_applications
  Backup.new(backup_ctx).tap do |backup|
    packages_glob = File.join(backup.backup_packages_path, '*.rb')
    backup.items = get_packages packages_glob, backup_ctx
  end
end

def package_from_files(packages_glob, ctx)
  ItemPackage.new(ctx).tap { |package| package.items = get_packages(packages_glob, ctx) }
end

private

# Finds package definitions inside of a particular path.
# @param string package_path Path to a script that contains package definitions.
def find_package_cls(package_path, io)
  return [] unless File.extname(package_path) == '.rb'

  mod = Module.new
  package_script = io.read package_path

  begin
    mod.class_eval package_script
  rescue Exception => e
    raise InvalidConfigFileError.new package_path, e
  end

  # Iterate over all constants/classes defined by the script.
  # If a constant defines a package return it.
  mod.constants.sort
    .map(&mod.method(:const_get))
    .select { |const| not const.nil? and const < Package }
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

end

# Add task helper methods into classes that contain context.

class SyncContext
  include Tasks

  def add_default_applications
    add_packages_from_cls APPLICATIONS
  end
end

class Package
  include Tasks
end

class Backup
  include Tasks
end

class BackupManager
  include Tasks
end

end
