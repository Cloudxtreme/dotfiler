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
  attr_reader :path

  def initialize(path)
    @path = path
  end
end

# A single backup directory present on a local computer.
# Discovered packages are packages which are not loaded by backup but have data.
class Backup
  attr_accessor :packages, :backup_packages_path
  DEFAULT_BACKUP_ROOT = File.expand_path '~/dotfiles'
  DEFAULT_BACKUP_DIR = File.join DEFAULT_BACKUP_ROOT, 'local'
  BACKUP_PACKAGES_PATH = '_packages'

  def initialize(ctx)
    @backup_packages_path = ctx.backup_path BACKUP_PACKAGES_PATH
    @ctx = ctx
    @packages = []
  end

  def backup_path
    @ctx.backup_path
  end

  # TODO(drognanar): Can we move discovery/update/enable_packages!/disable_packages! to BackupManager?
  def discover_packages
    existing_package_names = Set.new @packages.map { |package| package.name }
    apps.select { |application| application.should_execute and application.has_data and not existing_package_names.member?(application.name) }
  end

  def update_applications_file
    package_cls_to_add = @packages.map { |package| package.class }.select { |package_cls| APPLICATIONS.member? package_cls }

    applications_path = File.join @backup_packages_path, 'applications.rb'
    @ctx.io.mkdir_p @backup_packages_path
    @ctx.io.write applications_path, Setup::get_applications(package_cls_to_add)
  end

  # Finds packages that should be run under a given machine.
  # This will include packages that contain errors and do not have data.
  def packages_to_run
    @packages.select { |package| package.should_execute }
  end

  # TODO(drognanar): Can this be moved out to BackupManager?
  def enable_packages!(package_names)
    disable_packages! package_names
    @packages += apps.select { |application| package_names.member? application.name }
  end

  def disable_packages!(package_names)
    @packages = @packages.select { |package| not package_names.member? package.name }
  end

  # TODO(drognanar): Can we move resolve_backup to BackupManager?
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

  private

  def apps
    # TODO(drognanar): Perhaps just have an APPLICATION_NAME => APPLICATION_CLASS map?
    APPLICATIONS.map { |package_cls| package_cls.new @ctx }
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

  # Finds package definitions inside of a particular path.
  def BackupManager.find_package_cls(package_path, io)
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
      .map { |name| const = mod.const_get name }
      .select { |const| not const.nil? and const < Package }
  end

  # Constructs backup packages that can be found a package folder.
  def BackupManager.get_packages(packages_dir, ctx)
    (ctx.io.glob File.join(packages_dir, '*.rb'))
      .map { |package_path| BackupManager.find_package_cls(package_path, ctx.io) }
      .flatten
      .map { |package_cls| package_cls.new ctx }
  end

  def load_config!
    @backup_paths = @store.transaction(true) { |store| store.fetch('backups', []) }
  rescue PStore::Error
    raise InvalidConfigFileError.new @store.path
  end

  def load_backups!
    @backups = @backup_paths.map do |backup_path|
      ctx = @ctx.with_backup_root(backup_path)
      Backup.new(ctx).tap do |backup|
        backup.packages = BackupManager.get_packages backup.backup_packages_path, ctx
      end
    end
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
