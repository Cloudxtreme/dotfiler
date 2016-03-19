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
  attr_accessor :enabled_task_names, :disabled_task_names, :tasks, :backup_config_path
  DEFAULT_BACKUP_DIR = File.expand_path '~/dotfiles'

  # TODO: add host_info and backup dir?
  # TODO: move all management here?
  def initialize(backup_config, tasks, backup_config_path)
    @enabled_task_names = Set.new(backup_config['enabled_task_names'] || [])
    @disabled_task_names = Set.new(backup_config['disabled_task_names'] || [])
    @tasks = tasks
    @backup_config_path = backup_config_path
  end
  
  def enable_tasks(task_names)
    task_names = Set.new(task_names).intersection Set.new(tasks_to_run)
    @enabled_task_names += task_names
    @disabled_task_names -= task_names
  end
  
  def disable_tasks(task_names)
    task_names = Set.new(task_names).intersection Set.new(tasks_to_run)
    @enabled_task_name -= task_names
    @disabled_task_names += task_names
  end

  # Finds newly added tasks that can be run on this machine.
  # These tasks have not been yet added to the config file's enabled_task_names or disabled_task_names properties.
  def new_tasks
    @tasks.select { |task_name, task| task.should_execute and task.has_data and not is_enabled(task_name) and not is_disabled(task_name) }
  end

  # Finds tasks that should be run under a given machine.
  # This will include tasks that contain errors and do not have data.
  def tasks_to_run
    @tasks.select { |task_name, task| task.should_execute and is_enabled(task_name) }
  end

  def to_yml
    YAML.dump({'enabled_task_names' => @enabled_task_names.to_a, 'disabled_task_names' => @disabled_task_names.to_a})
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

# TODO: finish implementation of backups manager.
# TODO: handle missing data from backup manager.
class BackupManager
  DEFAULT_CONFIG_PATH = File.expand_path '~/dotfiles/config.yml'
  DEFAULT_BACKUP_CONFIG_PATH = './config.yml'
  BACKUP_TASKS_PATH = '_tasks'
  APPLICATIONS_DIR = Pathname(__FILE__).dirname().parent.parent.join('applications')
  DEFAULT_RESTORE_ROOT = File.expand_path '~/'

  def initialize(options = {})
    @host_info = options[:host_info] || Setup::get_host_info
    @io = options[:io]
    @configuration = YAML::store.new (options[:config_path] || DEFAULT_CONFIG_PATH)
  end
  
  def new_backup_tasks(backups)
    backups.map { |backup| [backup, backup.new_tasks] }
      .select { |_, new_tasks| not new_tasks.empty? }
  end
  
  # Detects any newly added apps/packages.
  # Queries the user to add newly defined applications in backups.
  # TODO: simplify together with print_new_tasks
  # TODO: possibly move outside of the backup manager class.
  def classify_new_tasks(backups = nil, &prompt_agree)
    backup_new_tasks = new_backup_tasks backups
    return if backup_new_tasks.empty?
    
    backups_print_new_tasks backups
    if prompt_agree.call
      update_backups { |backup| backup.enable_tasks backup.new_tasks }
    else
      update_backups { |backup| backup.disable_tasks backup.new_tasks }
      puts 'You can always add these apps later using "setup app add <app names>".'
    end
  end
  
  # TODO: used in lists.
  def backups_print_new_tasks(backups = nil)
    backups ||= get_backups
    backup_new_tasks = new_backup_tasks backups
    puts 'These applications can be backed up:'
    new_tasks_per_backup.each do |backup, new_tasks|
      puts backup.name
      puts new_tasks.map(&:name).join(' ')
    end
  end

  # Gets backups found on a given machine.
  def get_backups
    get_backup_paths.map do |backup_path|
      host_info = @host_info.merge backup_root: backup_path

      # TODO: Refactor this out?
      # TODO: what if yaml load fails?
      backup_config_path = File.join backup_path, DEFAULT_BACKUP_CONFIG_PATH
      backup_config = YAML.load File.read backup_config_path

      backup_tasks_path = Pathname(File.join backup_path, BACKUP_TASKS_PATH)
      backup_tasks = get_backup_tasks backup_tasks_path, host_info
      app_tasks = get_backup_tasks APPLICATIONS_DIR, host_info

      Backup.new backup_config, app_tasks.merge(backup_tasks), backup_config_path
    end
  end
  
  # Calls an update_block for all backups and updates their yaml configuration.
  def update_backups(*backups, &update_block)
    (backups || get_backups).map do |backup|
      update_block.call backup
      IO.write backup.backup_config_path, backup.to_yml
    end
  end

  # Creates a new backup and registers it in the global yaml configuration.
  def create_backup(resolved_backup)
    backup_dir, source_url = resolve_backup
    if File.exist?(backup_dir) and not Dir.entries(backup_dir).empty?
      puts "Cannot create backup. The folder #{backup_dir} already exists and is not empty."
    end
    
    @io.mkdir_p backup_dir
    @io.shell "git clone \"#{source_url}\" -o \"#{backup_dir}\"" if source_url
    @configuration.transaction { |store| store['backups'] << backup_dir }
  end

  # Gets the host info of the current machine.
  # TODO: handle multiple machine labels.
  def get_host_info
    {label: Config.machine_labels[0], restore_root: DEFAULT_RESTORE_ROOT, sync_time: Time.new}
  end

  private

  # Returns the paths where backups are kept.
  def get_backup_paths
    @configuration.transaction(true) { |store| store.fetch('backups', []) }
  end

  # Constructs a backup task given a task yaml configuration.
  def get_backup_task(task_path, host_info)
    # TODO: handle case when the task is an invalid file.
    SyncTask.new(YAML.load(task_path.read()), host_info, @io)
  end

  # Constructs backup tasks that can be found a task folder.
  def get_backup_tasks(tasks_path, host_info)
    return {} if not io.exist? tasks_path
    tasks_path.children
      .select { |path| path.extname == '.yml' }
      .map { |task_path| [File.basename(task_path, '.*'), get_backup_task(task_path, host_info)] }
      .to_h
  end
end

end # module Setup
