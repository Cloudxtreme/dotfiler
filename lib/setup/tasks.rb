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

# Returns one of APPLICATIONS that has app_name.
def app(app_name)
  # TODO: Get a relevant app from APPLICATIONS.
end

def backup(backup_dir)
  yield if block_given? and not ctx.io.exist? backup_dir

  # TODO: Deal with the case where the backup_dir is still missing.
  # TODO: Allow to provide a backup.rb file.
  backup_ctx = ctx.with_backup_dir(backup_dir)
  Backup.new(backup_ctx).tap do |backup|
    backup.items = get_packages backup.backup_packages_path, backup_ctx
  end
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
  rescue Exception
    raise InvalidConfigFileError.new package_path
  end

  # Iterate over all constants/classes defined by the script.
  # If a constant defines a package return it.
  mod.constants.sort
    .map(&mod.method(:const_get))
    .select { |const| not const.nil? and const < Package }
end

# Finds package definitions inside of a particular folder.
# @param string packages_dir Directory where packages should be found.
#                            Packages will be searched in every script file.
# @param SyncContext ctx Context that should be passed into packages.
def get_packages(packages_dir, ctx)
  (ctx.io.glob File.join(packages_dir, '*.rb'))
    .map { |package_path| find_package_cls(package_path, ctx.io) }
    .flatten
    .map { |package_cls| package_cls.new ctx }
end

end

# Add task helper methods into classes that contain context.

class SyncContext
  include Tasks
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
