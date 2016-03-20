# Allows to discover backups instances under a given machine.
require 'setup/io'
require 'setup/sync_task'
require 'setup/sync_task.platforms'

require 'pathname'
require 'yaml'
require 'yaml/store'

module Setup

# A single backup directory present on a local computer.
# It contains a config.yml file which defines the tasks that should be run for the backup operations.
# Enabled task names contains the list of tasks to be run.
# Disabled task names contains the list of tasks that should be skipped.
# New tasks are tasks for which there are any files to sync but are not part of any lists.
class Backup
  attr_accessor :enabled_task_names, :disabled_task_names, :tasks
  DEFAULT_BACKUP_DIR = File.expand_path '~/dotfiles'
  DEFAULT_BACKUP_CONFIG_PATH = 'config.yml'
  BACKUP_TASKS_PATH = '_tasks'
  APPLICATIONS_DIR = Pathname(__FILE__).dirname().parent.parent.join('applications')

  def initialize(backup_path, host_info, io, store_factory)
    host_info = host_info.merge backup_root: backup_path
    backup_config_path = Pathname(backup_path).join(DEFAULT_BACKUP_CONFIG_PATH)

    backup_tasks_path = Pathname(backup_path).join(BACKUP_TASKS_PATH)
    backup_tasks = get_backup_tasks backup_tasks_path, host_info, io
    app_tasks = get_backup_tasks APPLICATIONS_DIR, host_info, io
    @tasks = app_tasks.merge(backup_tasks)

    @store = store_factory.new backup_config_path
    @store.transaction(true) do |store|
      @enabled_task_names = Set.new(store.fetch('enabled_task_names', []))
      @disabled_task_names = Set.new(store.fetch('disabled_task_names', []))
    end
  end

  def enable_tasks(task_names)
    task_names_set = Set.new(task_names.map(&:downcase)).intersection Set.new(tasks.keys.map(&:downcase))
    @enabled_task_names += task_names_set
    @disabled_task_names -= task_names_set
    save_config if not task_names_set.empty?
  end

  def disable_tasks(task_names)
    task_names_set = Set.new(task_names.map(&:downcase)).intersection Set.new(tasks.keys.map(&:downcase))
    @enabled_task_names -= task_names_set
    @disabled_task_names += task_names_set
    save_config if not task_names_set.empty?
  end

  # Finds newly added tasks that can be run on this machine.
  # These tasks have not been yet added to the config file's enabled_task_names or disabled_task_names properties.
  def new_tasks
    @tasks.select { |task_name, task| not is_enabled(task_name) and not is_disabled(task_name) and task.should_execute and task.has_data }
  end

  # Finds tasks that should be run under a given machine.
  # This will include tasks that contain errors and do not have data.
  def tasks_to_run
    @tasks.select { |task_name, task| is_enabled(task_name) and task.should_execute }
  end

  def save_config
    @store.transaction { |s| s[:data] = {'enabled_task_names' => @enabled_task_names.to_a, 'disabled_task_names' => @disabled_task_names.to_a} }
  end

  def Backup.resolve_backup(backup_str, options)
    sep = backup_str.index ':'
    backup_dir = options[:backup_dir] || DEFAULT_BACKUP_DIR
    if not sep.nil?
      [File.expand_path(backup_str[0..sep-1]), backup_str[sep+1..-1]]
    elsif is_path(backup_str)
      [File.expand_path(backup_str), nil]
    else
      [File.expand_path(File.join(backup_dir, backup_str)), backup_str]
    end
  end

  private

  # Constructs a backup task given a task yaml configuration.
  def get_backup_task(task_path, host_info, io)
    config = YAML.load(io.read(task_path))
    SyncTask.new(config, host_info, io) if config
  end

  # Constructs backup tasks that can be found a task folder.
  def get_backup_tasks(tasks_path, host_info, io)
    return {} if not io.exist? tasks_path
    (io.entries tasks_path)
      .select { |path| path.extname == '.yml' }
      .map { |task_path| [File.basename(task_path, '.*'), get_backup_task(tasks_path.join(task_path), host_info, io)] }
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

class BackupManager
  DEFAULT_CONFIG_PATH = File.expand_path '~/dotfiles/config.yml'
  DEFAULT_RESTORE_ROOT = File.expand_path '~/'

  def initialize(options = {})
    @host_info = options[:host_info] || get_host_info
    @io = options[:io]
    @store_factory = options[:store_factory] || YAML::Store
    @store = @store_factory.new((options[:config_path] || DEFAULT_CONFIG_PATH))
  end

  # Gets backups found on a given machine.
  def get_backups
    get_backup_paths.map { |backup_path| Backup.new backup_path, @host_info, @io, @store_factory }
  end

  # Creates a new backup and registers it in the global yaml configuration.
  def create_backup(resolved_backup)
    backup_dir, source_url = resolved_backup
    backup_exists = @io.exist?(backup_dir)
    if backup_exists and not @io.entries(backup_dir).empty?
      puts "Cannot create backup. The folder #{backup_dir} already exists and is not empty."
      return
    end

    @io.mkdir_p backup_dir if not backup_exists
    @io.shell "git clone \"#{source_url}\" -o \"#{backup_dir}\"" if source_url
    @store.transaction { |store| store['backups'] = store['backups'] << backup_dir }
  end

  private

  # Gets the host info of the current machine.
  def get_host_info
    {label: Config.machine_labels, restore_root: DEFAULT_RESTORE_ROOT, sync_time: Time.new}
  end

  # Returns the paths where backups are kept.
  def get_backup_paths
    @store.transaction(true) { |store| store.fetch('backups', []) }
  end
end

end # module Setup
