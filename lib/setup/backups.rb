# Allows to discover backups instances under a given machine.
require 'setup/logging'
require 'setup/package'

require 'pathname'
require 'yaml'
require 'yaml/store'

module Setup

class InvalidConfigFileError < Exception
  attr_reader :path

  def initialize(path)
    @path = path
  end
end

# A single backup directory present on a local computer.
# It contains a config.yml file which defines the packages that should be run for the backup operations.
# Enabled package names contains the list of packages to be run.
# Disabled package names contains the list of packages that should be skipped.
# New packages are packages for which there are any files to sync but are not part of any lists.
class Backup
  attr_accessor :enabled_package_names, :disabled_package_names, :packages, :backup_path, :backup_packages_path
  DEFAULT_BACKUP_ROOT = File.expand_path '~/dotfiles'
  DEFAULT_BACKUP_DIR = File.join DEFAULT_BACKUP_ROOT, 'local'
  DEFAULT_BACKUP_CONFIG_PATH = 'config.yml'
  BACKUP_PACKAGES_PATH = '_packages'
  APPLICATIONS_DIR = Pathname(__FILE__).dirname().parent.parent.join('applications').to_s

  def initialize(backup_path, ctx, store)
    @backup_path = backup_path
    @backup_packages_path = File.join(@backup_path, BACKUP_PACKAGES_PATH)
    @ctx = ctx
    @store = store

    @packages = {}
    @enabled_package_names = Set.new
    @disabled_package_names = Set.new
  end

  def Backup.from_config(backup_path: nil, ctx: {})
    ctx.io.mkdir_p backup_path
    ctx = ctx.with_options backup_root: backup_path
    backup_config_path = File.join(backup_path, DEFAULT_BACKUP_CONFIG_PATH)
    store = YAML::Store.new backup_config_path
    Backup.new(backup_path, ctx, store).tap(&:load_config!)
  end

  # Loads the configuration and the packages.
  def load_config!
    @store.transaction(true) do |store|
      @enabled_package_names = Set.new(store.fetch('enabled_package_names', []))
      @disabled_package_names = Set.new(store.fetch('disabled_package_names', []))
    end

    backup_packages = get_packages @backup_packages_path
    app_packages = get_packages APPLICATIONS_DIR
    @packages = app_packages.merge(backup_packages)
  rescue PStore::Error
    raise InvalidConfigFileError.new @store.path
  end

  def save_config!
    return if @ctx.io.dry
    @store.transaction(false) do |store|
      store['enabled_package_names'] = @enabled_package_names.to_a
      store['disabled_package_names'] = @disabled_package_names.to_a
    end
  end

  def enable_packages!(package_names)
    package_names_set = Set.new(package_names.map(&:downcase)).intersection Set.new(packages.keys.map(&:downcase))
    @enabled_package_names += package_names_set
    @disabled_package_names -= package_names_set
    save_config! if not package_names_set.empty?
  end

  def disable_packages!(package_names)
    package_names_set = Set.new(package_names.map(&:downcase)).intersection Set.new(packages.keys.map(&:downcase))
    @enabled_package_names -= package_names_set
    @disabled_package_names += package_names_set
    save_config! if not package_names_set.empty?
  end

  # Finds newly added packages that can be run on this machine.
  # These packages have not been yet added to the config file's enabled_package_names or disabled_package_names properties.
  def new_packages
    @packages.select { |package_name, package| not is_enabled(package_name) and not is_disabled(package_name) and package.should_execute and package.has_data }
  end

  # Finds packages that should be run under a given machine.
  # This will include packages that contain errors and do not have data.
  def packages_to_run
    @packages.select { |package_name, package| is_enabled(package_name) and package.should_execute }
  end

  # This method resolves a commandline backup name into a backup path/source path pair.
  # For instance resolve_backup `~/dotfiles` should resolve to backup `~/dotfiles` but no source.
  # resolve_backup `github.com/repo` should resolve to backup in `~/dotfiles/github.com/repo` with source at `github.com/repo`.
  def Backup.resolve_backup(backup_str, options)
    sep = backup_str.index ';'
    backup_dir = options[:backup_dir] || DEFAULT_BACKUP_ROOT

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
      resolved_backup = File.expand_path(File.join(backup_dir, resolved_backup))
    end

    if resolved_source == ''
      resolved_source = nil
    end

    if not resolved_source.nil? and not is_path(resolved_source)
      resolved_source = "https://#{resolved_source}"
    end

    [File.expand_path(resolved_backup), resolved_source]
  end

  # Constructs a backup package given a package script.
  def Backup.get_package(package_path, ctx)
    return unless File.extname(package_path) == '.rb'

    mod = Module.new
    package_script = ctx.io.read package_path

    begin
      mod.class_eval package_script
    rescue Exception
      raise InvalidConfigFileError.new package_path
    end

    # Iterate over all constants/classes defined by the script.
    # If a constant defines a package return it.
    mod.constants.map do |name|
      const = mod.const_get name
      if not const.nil? and const < Package
        return const.new ctx
      end
    end
  end

  private

  # Constructs backup packages that can be found a package folder.
  def get_packages(packages_dir)
    (@ctx.io.glob File.join(packages_dir, '*.rb'))
      .map { |package_path| [File.basename(package_path, '.*'), Backup.get_package(package_path, @ctx)] }
      .select { |package_name, package| not package.nil? }
      .to_h
  end

  def is_enabled(package_name)
    @enabled_package_names.any? { |enabled_package_name| enabled_package_name.casecmp(package_name) == 0 }
  end

  def is_disabled(package_name)
    @disabled_package_names.any? { |disabled_package_name| disabled_package_name.casecmp(package_name) == 0 }
  end

  def Backup.is_path(path)
    path.start_with?('..') || path.start_with?('.') || path.start_with?('~') || Pathname.new(path).absolute?
  end
end

class BackupManager
  attr_accessor :backups, :backup_paths
  DEFAULT_CONFIG_PATH = File.expand_path '~/setup.yml'

  def initialize(ctx = nil, store = nil)
    @ctx = ctx
    @store = store
  end

  # Loads backup manager configuration and backups it references.
  def BackupManager.from_config(ctx)
    store = YAML::Store.new(DEFAULT_CONFIG_PATH)

    BackupManager.new(ctx, store).tap(&:load_config!)
  end

  def load_config!
    @backup_paths = @store.transaction(true) { |store| store.fetch('backups', []) }
  rescue PStore::Error
    raise InvalidConfigFileError.new @store.path
  end

  def load_backups!
    @backups = @backup_paths.map { |backup_path| Backup.from_config backup_path: backup_path, ctx: @ctx }
  end

  def save_config!
    @store.transaction(false) { |store| store['backups'] = @backup_paths } unless @ctx.io.dry
  end

  # Creates a new backup and registers it in the global yaml configuration.
  def create_backup!(resolved_backup, force: false)
    backup_dir, source_url = resolved_backup

    if @backup_paths.include? backup_dir
      LOGGER.warn "Backup \"#{backup_dir}\" already exists"
      return
    end

    LOGGER << "Creating a backup at \"#{backup_dir}\"\n"

    # TODO(drognanar): Revise this model.
    # TODO(drognanar): Will not clone the repository if folder exists but will sync.
    backup_exists = @ctx.io.exist?(backup_dir)
    if not backup_exists or @ctx.io.entries(backup_dir).empty?
      @ctx.io.mkdir_p backup_dir if not backup_exists
      if source_url
        LOGGER.info "Cloning repository \"#{source_url}\""
        @ctx.io.shell "git clone \"#{source_url}\" -o \"#{backup_dir}\""
      end
    elsif not force
      LOGGER.warn "Cannot create backup. The folder #{backup_dir} already exists and is not empty."
      return
    end

    LOGGER.verbose "Updating \"#{@store.path}\""
    @backup_paths = @backup_paths << backup_dir
    save_config!
  end
end

end # module Setup
