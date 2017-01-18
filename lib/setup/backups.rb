# Allows to discover backups instances under a given machine.
require 'setup/applications'
require 'setup/logging'
require 'setup/package'
require 'setup/package_template'

require 'pathname'
require 'yaml'
require 'yaml/store'

module Setup

class InvalidConfigFileError < Exception
  attr_reader :path, :inner_exception

  def initialize(path, inner_exception)
    @path = path
    @inner_exception = inner_exception
  end
end

# A single backup directory present on a local computer.
# Discovered packages are packages which are not loaded by backup but have data.
class Backup < ItemPackage
  BACKUP_PACKAGES_PATH = '_packages'

  def backup_packages_path
    ctx.backup_path BACKUP_PACKAGES_PATH
  end

  # TODO(drognanar): Can we move discovery/update/enable_packages!/disable_packages! to BackupManager?
  # TODO(drognanar): Can we get rid of discovery?
  def discover_packages
    existing_package_names = Set.new @items.map { |package| package.name }
    packages.values.select { |application| application.has_data and not existing_package_names.member?(application.name) }
  end

  def update_applications_file
    package_cls_to_add = @items.map { |package| package.class }.select { |package_cls| APPLICATIONS.member? package_cls }

    applications_path = File.join backup_packages_path, 'applications.rb'
    io.mkdir_p backup_packages_path
    io.write applications_path, Setup::Templates::applications(package_cls_to_add)
  end

  # TODO(drognanar): Can this be moved out to BackupManager?
  def enable_packages!(package_names)
    disable_packages! package_names
    @items += package_names.map { |package_name| packages[package_name] }
  end

  def disable_packages!(package_names)
    @items = @items.select { |package| not package_names.member? package.name }
  end
end

# TODO(drognanar): Slowly deprecate BackupManager.
# TODO(drognanar): Having to deal with another global config file makes things more confusing.
class BackupManager < ItemPackage
  attr_accessor :backup_paths
  DEFAULT_CONFIG_PATH = File.expand_path '~/setup.yml'

  def initialize(ctx = nil, store = nil)
    super(ctx)
    @store = store
  end

  # Loads backup manager configuration and backups it references.
  def BackupManager.from_config(ctx)
    store = YAML::Store.new(DEFAULT_CONFIG_PATH)
    BackupManager.new(ctx, store)
  end

  def load_backups!
    @backup_paths = @store.transaction(true) { |store| store.fetch('backups', []) }
    logger.verbose "Loading backups: #{@backup_paths}"
    @items = @backup_paths.map(&method(:backup))
  rescue PStore::Error => e
    raise InvalidConfigFileError.new @store.path, e
  end

  def save_config!
    @store.transaction(false) { |store| store['backups'] = @backup_paths } unless io.dry
  end
end

module Backups

def self.create_backup(path, logger, io, force: false)
  logger << "Creating a backup at \"#{path}\"\n"

  if io.exist?(path) and not io.entries(path).empty? and not force
    logger.warn "Cannot create backup. The folder #{path} already exists and is not empty."
    return
  end

  io.mkdir_p path
  io.write(File.join(path, 'backups.rb'), Setup::Templates::backups)
  io.write(File.join(path, 'sync.rb'), Setup::Templates::sync)
end

end

end # module Setup
