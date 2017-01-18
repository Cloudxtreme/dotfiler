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
  DEFAULT_BACKUP_ROOT = File.expand_path '~/dotfiles'
  DEFAULT_BACKUP_DIR = File.join DEFAULT_BACKUP_ROOT, 'local'
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

  # TODO(drognanar): Can we move resolve_backup to BackupManager?
  # This method resolves a commandline backup name into a backup path/source path pair.
  # For instance resolve_backup `~/dotfiles` should resolve to backup `~/dotfiles` but no source.
  # resolve_backup `github.com/repo` should resolve to backup in `~/dotfiles/github.com/repo` with source at `github.com/repo`.
  def Backup.resolve_backup(backup_str, options)
    sep = backup_str.index ';'
    backup_root = options[:backup_root] || DEFAULT_BACKUP_ROOT

    if not sep.nil?
      resolved_backup = backup_str[0..sep-1]
      resolved_source = backup_str[sep+1..-1]
    elsif is_path backup_str
      resolved_backup = backup_str
      resolved_source = nil
    else
      resolved_backup = backup_str
      resolved_source = backup_str
    end

    if not is_path(resolved_backup)
      resolved_backup = File.expand_path(File.join(backup_root, resolved_backup))
    end

    if resolved_source == ''
      resolved_source = nil
    end

    if not resolved_source.nil? and not is_path(resolved_source)
      resolved_source = "https://#{resolved_source}"
    end

    [File.expand_path(resolved_backup), resolved_source]
  end

  private

  def Backup.is_path(path)
    path.start_with?('..') || path.start_with?('.') || path.start_with?('~') || Pathname.new(path).absolute?
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

  # Creates a new backup and registers it in the global yaml configuration.
  def create_backup!(resolved_backup, force: false)
    backup_dir, _ = resolved_backup

    logger << "Creating a backup at \"#{backup_dir}\"\n"

    if io.exist?(backup_dir) and not io.entries(backup_dir).empty? and not force
      logger.warn "Cannot create backup. The folder #{backup_dir} already exists and is not empty."
      return
    end

    logger.verbose "Updating \"#{@store.path}\""
    @backup_paths = @backup_paths << backup_dir
    save_config!
  end
end

end # module Setup
