# Allows to discover backups instances under a given machine.
require 'setup/io'
require 'setup/logging'
require 'setup/package'
require 'setup/platform'

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
# It contains a config.yml file which defines the tasks that should be run for the backup operations.
# Enabled task names contains the list of tasks to be run.
# Disabled task names contains the list of tasks that should be skipped.
# New tasks are tasks for which there are any files to sync but are not part of any lists.
class Backup
  attr_accessor :enabled_task_names, :disabled_task_names, :tasks, :backup_path, :backup_tasks_path
  DEFAULT_BACKUP_ROOT = File.expand_path '~/dotfiles'
  DEFAULT_BACKUP_DIR = File.join DEFAULT_BACKUP_ROOT, 'local'
  DEFAULT_BACKUP_CONFIG_PATH = 'config.yml'
  BACKUP_TASKS_PATH = '_tasks'
  APPLICATIONS_DIR = Pathname(__FILE__).dirname().parent.parent.join('applications').to_s

  def initialize(backup_path, ctx, io, store)
    @backup_path = backup_path
    @backup_tasks_path = File.join(@backup_path, BACKUP_TASKS_PATH)
    @ctx = ctx
    @io = io
    @store = store

    @tasks = {}
    @enabled_task_names = Set.new
    @disabled_task_names = Set.new
  end

  def Backup.from_config(backup_path: nil, ctx: {}, io: nil)
    io.mkdir_p backup_path
    ctx = ctx.with_options backup_root: backup_path
    backup_config_path = File.join(backup_path, DEFAULT_BACKUP_CONFIG_PATH)
    store = YAML::Store.new backup_config_path
    Backup.new(backup_path, ctx, io, store).tap(&:load_config!)
  end

  # Loads the configuration and the tasks.
  def load_config!
    @store.transaction(true) do |store|
      @enabled_task_names = Set.new(store.fetch('enabled_task_names', []))
      @disabled_task_names = Set.new(store.fetch('disabled_task_names', []))
    end

    backup_tasks = get_backup_tasks @backup_tasks_path, @ctx, @io
    app_tasks = get_backup_tasks APPLICATIONS_DIR, @ctx, @io
    @tasks = app_tasks.merge(backup_tasks)
  rescue PStore::Error
    raise InvalidConfigFileError.new @store.path
  end

  def save_config!
    return if @io.dry
    @store.transaction(false) do |store|
      store['enabled_task_names'] = @enabled_task_names.to_a
      store['disabled_task_names'] = @disabled_task_names.to_a
    end
  end

  def enable_tasks!(task_names)
    task_names_set = Set.new(task_names.map(&:downcase)).intersection Set.new(tasks.keys.map(&:downcase))
    @enabled_task_names += task_names_set
    @disabled_task_names -= task_names_set
    save_config! if not task_names_set.empty?
  end

  def disable_tasks!(task_names)
    task_names_set = Set.new(task_names.map(&:downcase)).intersection Set.new(tasks.keys.map(&:downcase))
    @enabled_task_names -= task_names_set
    @disabled_task_names += task_names_set
    save_config! if not task_names_set.empty?
  end

  def load_context(ctx)
    @tasks.each { |task_name, task| task.load_context ctx }
  end

  # Finds newly added tasks that can be run on this machine.
  # These tasks have not been yet added to the config file's enabled_task_names or disabled_task_names properties.
  def new_tasks
    # TODO(drognanar): Use new_package?
    # TODO(drognanar): Then make is_enabled == not is_disabled.
    # TODO(drognanar): Get rid of enabled and just keep ignored.
    # TODO(drognanar): Rename task to package.
    @tasks.select { |task_name, task| not is_enabled(task_name) and not is_disabled(task_name) and task.should_execute and task.has_data }
  end

  # Finds tasks that should be run under a given machine.
  # This will include tasks that contain errors and do not have data.
  def tasks_to_run
    @tasks.select { |task_name, task| is_enabled(task_name) and task.should_execute }
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

  private

  def get_backup_task_from_ruby_file(task_pathname, host_info, io)
    mod = Module.new
    package_script = io.read task_pathname
    mod.class_eval package_script

    # Iterate over all constants/classes defined by the script.
    # If a constant defines a package return it.
    mod.constants.map do |name|
      const = mod.const_get name
      if not const.nil? and const < PackageBase
        return const.new host_info, io
      end
    end
  end

  def get_backup_task_from_yaml_file(task_pathname, host_info, io)
    config = YAML.load(io.read(task_pathname))
    if config.nil?
      raise InvalidConfigFileError.new task_pathname
    end

    Package.new(config, host_info, io)
  end

  # Constructs a backup task given a task yaml configuration.
  def get_backup_task(task_pathname, host_info, io)
    if File.extname(task_pathname) == '.rb'
      get_backup_task_from_ruby_file task_pathname, host_info, io
    elsif File.extname(task_pathname) == '.yaml' or File.extname(task_pathname) == '.yml'
      get_backup_task_from_yaml_file task_pathname, host_info, io
    end
  end

  # Constructs backup tasks that can be found a task folder.
  # TODO: load with context.
  def get_backup_tasks(tasks_path, host_info, io)
    (io.glob [File.join(tasks_path, '*.yml'), File.join(tasks_path, '*.rb')])
      .map { |task_path| [File.basename(task_path, '.*'), get_backup_task(task_path, host_info, io)] }
      .select { |task_name, task| not task.nil? }
      .to_h
  end

  def is_enabled(task_name)
    @enabled_task_names.any? { |enabled_task_name| enabled_task_name.casecmp(task_name) == 0 }
  end

  def is_disabled(task_name)
    @disabled_task_names.any? { |disabled_task_name| disabled_task_name.casecmp(task_name) == 0 }
  end

  def Backup.is_path(path)
    path.start_with?('..') || path.start_with?('.') || path.start_with?('~') || Pathname.new(path).absolute?
  end
end

# TODO(drognanar): Embed labels into the global configs file?
# TODO(drognanar): Add a label for a local machine.
class BackupManager
  attr_accessor :backups, :backup_paths
  DEFAULT_CONFIG_PATH = File.expand_path '~/setup.yml'
  DEFAULT_RESTORE_ROOT = File.expand_path '~/'

  def initialize(ctx = nil, io = nil, store = nil)
    @ctx = ctx
    @io = io
    @store = store
  end

  # Loads backup manager configuration and backups it references.
  def BackupManager.from_config(ctx: nil, io: nil)
    # TODO(drognanar): How to add extra labels into host_info?
    # TODO(drognanar): These can only be obtained after running #load_config!
    # TODO(drognanar): Hardcode the config path?
    # TODO(drognanar): What if we get pluggable packages?
    ctx ||= SyncContext.new
    ctx = ctx.with_options BackupManager.get_host_info

    store = YAML::Store.new(DEFAULT_CONFIG_PATH)

    BackupManager.new(ctx, io, store).tap(&:load_config!)
  end

  def load_config!
    @backup_paths = @store.transaction(true) { |store| store.fetch('backups', []) }
  rescue PStore::Error
    raise InvalidConfigFileError.new @store.path
  end

  def load_backups!
    @backups = @backup_paths.map { |backup_path| Backup.from_config backup_path: backup_path, ctx: @ctx, io: @io }
  end

  def save_config!
    @store.transaction(false) { |store| store['backups'] = @backup_paths } unless @io.dry
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
    backup_exists = @io.exist?(backup_dir)
    if not backup_exists or @io.entries(backup_dir).empty?
      @io.mkdir_p backup_dir if not backup_exists
      if source_url
        LOGGER.info "Cloning repository \"#{source_url}\""
        @io.shell "git clone \"#{source_url}\" -o \"#{backup_dir}\""
      end
    elsif not force
      LOGGER.warn "Cannot create backup. The folder #{backup_dir} already exists and is not empty."
      return
    end

    LOGGER.verbose "Updating \"#{@store.path}\""
    @backup_paths = @backup_paths << backup_dir
    save_config!
  end

  private

  # Gets the host info of the current machine.
  # TODO(drognanar): Can this be redesigned?
  # TODO(drognanar): Convert into context?
  def BackupManager.get_host_info
    { restore_root: DEFAULT_RESTORE_ROOT, sync_time: Time.new }
  end
end

end # module Setup
