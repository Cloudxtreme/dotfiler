# Allows to discover backups instances under a given machine.
require 'setup/io'
require 'setup/sync_task'

require 'pathname'
require 'yaml'

module Setup

DEFAULT_CONFIG_PATH = File.expand_path "~/dotfiles/config.yml"
DEFAULT_BACKUP_CONFIG_PATH = "./config.yml"
BACKUP_TASKS_PATH = "_tasks"
SCRIPT_PATH = Pathname(__FILE__).dirname()
APPLICATIONS_DIR = SCRIPT_PATH.parent.parent.join('applications')

class Backup
  attr_reader :enabled_task_names, :disabled_task_names, :tasks, :backup_path

  def initialize(backup_config, tasks, backup_path)
    @enabled_task_names = backup_config['enabled_task_names'] || []
    @disabled_task_names = backup_config['disabled_task_names'] || []
    @tasks = tasks
    @backup_path = backup_path
  end

  # Finds newly added tasks that can be run on this machine.
  # These tasks have not been yet added to the config file.
  def new_tasks
    @tasks.select { |task_name, task| task.should_execute and task.has_data and not is_enabled(task_name) and not is_disabled(task_name) }
  end

  # Finds tasks that should be run under a given machine.
  # This will include tasks that contain errors and do not have data.
  def tasks_to_run
    @tasks.select { |task_name, task| task.should_execute and is_enabled(task_name) }
  end

  def to_yml
    YAML.dump({'enabled_task_names' => @enabled_task_names, 'disabled_task_names' => @disabled_task_names})
  end

  private

  def is_enabled(task_name)
    @enabled_task_names.any? { |enabled_task_name| enabled_task_name.casecmp(task_name) == 0 }
  end

  def is_disabled(task_name)
    @disabled_task_names.any? { |disabled_task_name| disabled_task_name.casecmp(task_name) == 0 }
  end
end

def Setup.get_backups(io = CONCRETE_IO, config_path = nil, host_info = nil)
  host_info ||= get_host_info
  get_backup_paths(config_path).map do |backup_path|
    host_info = host_info.merge backup_root: backup_path

    backup_config_path = File.join backup_path, DEFAULT_BACKUP_CONFIG_PATH
    backup_config = YAML.load File.read backup_config_path

    backup_tasks_path = Pathname(File.join backup_path, BACKUP_TASKS_PATH)
    backup_tasks = get_backup_tasks backup_tasks_path, host_info, io
    app_tasks = get_backup_tasks APPLICATIONS_DIR, host_info, io

    Backup.new backup_config, app_tasks.merge(backup_tasks), backup_path
  end
end

def Setup.get_new_tasks(backups)
  backups.map { |backup| [backup, backup.new_tasks] }
end

def Setup.backups_print_new_tasks(backups = nil)
  new_tasks_per_backup = get_new_tasks(backups || get_backups)
    .select { |_, new_tasks| not new_tasks.empty? }
  return if new_tasks_per_backup.empty? 
  
  puts 'These applications can be backed up:'
  new_tasks_per_backup.each do |backup, new_tasks|
    puts backup.name
    puts new_tasks.map(&:name).join(' ')
  end
end

# Detects any newly added apps/packages.
# Queries the user to add newly defined applications in backups.
def Setup.classify_new_tasks(backups = nil, &agree)
  backup_new_tasks = backups.map { |backup| [backup, backup.new_tasks] }
  return if backup_new_tasks.all? { |backup, new_tasks| new_tasks.empty? }
  Setup::backups_print_new_tasks backups

  if agree.call
    backup_new_tasks.each do |backup, new_tasks|
      Setup::backups_add_tasks new_tasks, [backup]
    end
  else
    puts 'You can always add these apps later using "setup app add <app names>".'
  end
end

# TODO: Allow to specify for which backup to add the task.
def Setup.backups_add_tasks(names, backups = nil)
  names_set = Set.new names
  (backups || Setup::get_backups).each do |backup|
    tasks_to_add = Set.new(backup.disabled_task_names).intersection names_set
    if not intersection.empty?
      backup.enabled_task_names += tasks_to_add
      backup.disabled_task_names -= tasks_to_add
      IO.write backup.backup_path, backup.to_yml
    end
  end
end

# TODO: Allow to specify for which backup to add the task.
def Setup.backups_remove_tasks(names, backups = nil)
  names_set = Set.new names
  (backups || Setup::get_backups).each do |backup|
    tasks_to_remove = Set.new(backup.enabled_task_names).intersection names_set
    if not tasks_to_remove.empty?
      backup.enabled_task_names -= tasks_to_remove
      backup.disabled_task_names += tasks_to_remove
      IO.write backup.backup_path, backup.to_yml
    end
  end
end

# TODO: perform proper label detection.
DEFAULT_LABEL = '<win>'
DEFAULT_RESTORE_ROOT = File.expand_path "~/"
def Setup.get_host_info
  {label: DEFAULT_LABEL, restore_root: DEFAULT_RESTORE_ROOT, sync_time: Time.new}
end

private

def Setup.get_backup_paths(config_path = nil)
  config_path ||= DEFAULT_CONFIG_PATH
  main_config = YAML.load File.read config_path
  main_config['backups']
end

def Setup.get_backup_task(task_path, host_info, io)
  SyncTask.new(YAML.load(task_path.read()), host_info, io)
end

def Setup.init_backups(backups)
end

def Setup.get_backup_tasks(tasks_path, host_info, io)
  return {} if not io.exist? tasks_path
  tasks_path.children
    .select { |path| path.extname == '.yml' }
    .map { |task_path| [File.basename(task_path, '.*'), get_backup_task(task_path, host_info, io)] }
    .to_h
end

end # module Setup
