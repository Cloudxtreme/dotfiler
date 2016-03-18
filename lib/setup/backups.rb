# Allows to discover backups instances under a given machine.
require 'setup/io'
require 'setup/sync_task'
require 'setup/sync_task.platforms'

require 'pathname'
require 'yaml'
require 'yaml/store'

module Setup

class Backup
  attr_reader :enabled_task_names, :disabled_task_names, :tasks, :backup_config_path

  def initialize(backup_config, tasks, backup_config_path)
    @enabled_task_names = backup_config['enabled_task_names'] || []
    @disabled_task_names = backup_config['disabled_task_names'] || []
    @tasks = tasks
    @backup_config_path = backup_config_path
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

# TODO: finish implementation of backups manager.
# TODO: handle missing data from backup manager.
class BackupManager
  DEFAULT_CONFIG_PATH = File.expand_path '~/dotfiles/config.yml'
  DEFAULT_BACKUP_CONFIG_PATH = './config.yml'
  BACKUP_TASKS_PATH = '_tasks'
  APPLICATIONS_DIR = Pathname(__FILE__).dirname().parent.parent.join('applications')
  DEFAULT_BACKUP_DIR = File.expand_path '~/dotfiles'
  DEFAULT_BACKUP_ROOT = File.expand_path '~/dotfiles/local'
  DEFAULT_RESTORE_ROOT = File.expand_path '~/'

  def initialize(options = {})
    @config_path = options[:config_path] || DEFAULT_CONFIG_PATH
    @host_info = options[:host_info] || Setup::get_host_info
    @io = options[:io]
    @store = nil
  end
  
  # Detects any newly added apps/packages.
  # Queries the user to add newly defined applications in backups.
  def classify_new_tasks(backups = nil, &prompt_agree)
    backup_new_tasks = backups.map { |backup| [backup, backup.new_tasks] }
    return if backup_new_tasks.all? { |backup, new_tasks| new_tasks.empty? }
    backups_print_new_tasks backups

    if prompt_agree.call
      backup_new_tasks.each do |backup, new_tasks|
        backups_add_tasks new_tasks, [backup]
      end
    else
      puts 'You can always add these apps later using "setup app add <app names>".'
    end
  end
  
  def backups_print_new_tasks(backups = nil)
    backups ||= get_backups
    new_tasks_per_backups = backups.map { |backup| [backup, backup.new_tasks] }
      .select { |_, new_tasks| not new_tasks.empty? }
    return if new_tasks_per_backup.empty? 
    
    puts 'These applications can be backed up:'
    new_tasks_per_backup.each do |backup, new_tasks|
      puts backup.name
      puts new_tasks.map(&:name).join(' ')
    end
  end

  def get_backups
    get_backup_paths.map do |backup_path|
      host_info = @host_info.merge backup_root: backup_path

      # Refactor this out?
      backup_config_path = File.join backup_path, DEFAULT_BACKUP_CONFIG_PATH
      backup_config = YAML.load File.read backup_config_path

      backup_tasks_path = Pathname(File.join backup_path, BACKUP_TASKS_PATH)
      backup_tasks = get_backup_tasks backup_tasks_path
      app_tasks = get_backup_tasks APPLICATIONS_DIR

      Backup.new backup_config, app_tasks.merge(backup_tasks), backup_config_path
    end
  end
  
  # TODO: Allow to specify for which backup to add the task.
  def backups_add_tasks(names, backups = nil)
    names_set = Set.new names
    (backups || Setup::get_backups).each do |backup|
      tasks_to_add = Set.new(backup.disabled_task_names).intersection names_set
      backup.enabled_task_names += tasks_to_add
      backup.disabled_task_names -= tasks_to_add
      IO.write backup.backup_config_path, backup.to_yml
    end
  end

  # TODO: Allow to specify for which backup to add the task.
  def backups_remove_tasks(names, backups = nil)
    names_set = Set.new names
    (backups || Setup::get_backups).each do |backup|
      tasks_to_remove = Set.new(backup.enabled_task_names).intersection names_set
      backup.enabled_task_names -= tasks_to_remove
      backup.disabled_task_names += tasks_to_remove
      IO.write backup.backup_config_path, backup.to_yml
    end
  end

  def create_backup(resolved_backup)

    backup_dir, source_url = resolve_backup
    @io.mkdir_p backup_dir
    @io.shell "git clone \"#{source_url}\" -o \"#{backup_dir}\"" if source_url

    get_store.transaction do |store|
      store['backups'] << backup_dir
      store.commit
    end
  end

  def BackupManager.resolve_backups(backup_strs, options = {})
    if backup_strs.empty?
      backup_strs = [DEFAULT_BACKUP_ROOT]
    end

    backup_strs.map { |backup_str| resolve_backup(backup_str, options) }
  end

  def init_backups(backup_strs, options)
    resolved_backups = resolve_backups(backup_strs, options)
    resolved_backups.each &method(:create_backup)
    restore
    backup
  end

  def get_host_info
    {label: Config.machine_labels[0], restore_root: DEFAULT_RESTORE_ROOT, sync_time: Time.new}
  end

  private
  
  def get_store
    @store ||= YAML::store.new @config_path
  end
  
  def BackupManager.is_path(path)
    path.start_with?('..') || path.start_with?('.') || path.start_with?('~') || Pathname.new(path).absolute?
  end

  def BackupManager.resolve_backup(backup_str, options)
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

  def get_backup_paths
    get_store.transaction { |store| store['backups'] }
  end

  def get_backup_task(task_path)
    SyncTask.new(YAML.load(task_path.read()), @host_info, @io)
  end

  def get_backup_tasks(tasks_path)
    return {} if not io.exist? tasks_path
    tasks_path.children
      .select { |path| path.extname == '.yml' }
      .map { |task_path| [File.basename(task_path, '.*'), get_backup_task(task_path)] }
      .to_h
  end
end

end # module Setup
