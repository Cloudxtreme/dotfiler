# Setup::Tasks provides method helpers to generate tasks
# within contexts that include a sync context. It also adds
# these helpers into the following classes: SyncContext/
# Package/Backup/BackupManager.
require 'setup/backups'
require 'setup/package'
require 'setup/sync_context'

module Setup
module Tasks

# Adds a new file sync task.
def file(filepath, options = {})
  FileSyncTask.new(filepath, options, ctx)
end

def app(app_name)
  # TODO: Get a relevant app from APPLICATIONS.
end

def backup(backup_path)
  unless ctx.io.exist? backup_path
    yield if block_given?
  end

  # TODO: Allow to provide a backup.rb file.
  backup_ctx = ctx.with_backup_root(backup_path)
  Backup.new(backup_ctx).tap do |backup|
    backup.items = get_packages backup.backup_packages_path, backup_ctx
  end
end

private

# Finds package definitions inside of a particular path.
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

# Constructs backup packages that can be found a package folder.
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