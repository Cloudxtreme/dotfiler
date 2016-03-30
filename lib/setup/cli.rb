require 'setup/io'
require 'setup/backups'

require 'highline'
require 'ruby-progressbar'
require 'thor'

# TODO(drognanar): improve summary output per task
# TODO(drognanar): make this more output friendly.
# TODO(drognanar): perhaps get rid of the progressbar and just print output directory to stdout.
# TODO(drognanar): and make it quite verbose by default.
# TODO(drognanar): add logging somewhere?
# TODO(drognanar): possibly s/app/package

module Setup
module Cli

Commandline = HighLine.new

module CliHelpers
  def get_io(options = {})
    options[:dry] ? DRY_IO : CONCRETE_IO
  end

  def with_backup_manager(options = {})
    begin
      backup_manager = Setup::BackupManager.from_config(io: get_io(options), config_path: options[:config])
      backup_manager.load_backups!
      yield backup_manager
      return true
    rescue InvalidConfigFileError => e
      $stderr.puts 'Failed to get backup manager'
      $stderr.puts "#{e}"
      return false
    end
  end
end

class AppCLI < Thor
  no_commands do
    include CliHelpers
    
    def print_apps(backup, options)
      puts 'Enabled apps:'
      puts backup.enabled_task_names.to_a.join(', ')
      puts "\nDisabled apps:"
      puts backup.disabled_task_names.to_a.join(', ')
      puts "\nNew apps:"
      puts backup.new_tasks.keys.join(', ')
    end
  end

  desc 'add [<names>...]', 'Adds app\'s settings to the backup.'
  option 'config', type: :string
  def add(*names)
    with_backup_manager(options) do |backup_manager|
      backup_manager.backups.map { |backup| backup.enable_tasks! names }
    end
  end

  desc 'remove [<name>...]', 'Removes app\'s settings from the backup.'
  option 'config', type: :string
  def remove(*names)
    with_backup_manager(options) do |backup_manager|
      backup_manager.backups.map { |backup| backup.disable_tasks! names }
    end
  end

  desc 'list', 'Lists apps for which settings can be backed up.'
  option 'config', type: :string
  def list
    with_backup_manager(options) do |backup_manager|
      backup_manager.backups.each do |backup|
        puts "backup: #{backup.backup_path}" if backup_manager.backups.length > 1
        print_apps backup, options
      end
    end
  end
end

class SetupCLI < Thor
  no_commands do
    include CliHelpers

    # Prompts to enable new tasks.
    def prompt_to_enable_new_tasks(backups_with_new_tasks, options)
      if options[:enable_new] == 'prompt'
        puts 'These applications can be backed up:'
        backups_with_new_tasks.each do |backup|
          puts backup.backup_path
          puts backup.new_tasks.keys.join(' ')
        end
      end

      # TODO(drognanar): validate json schemas
      puts options[:enable_new]
      prompt_accept = (options[:enable_new] == 'prompt' and Commandline.agree('Backup all of these applications? [y/n]'))
      if options[:enable_new] == 'all' or prompt_accept
        backups_with_new_tasks.each { |backup| backup.enable_tasks! backup.new_tasks.keys }
      else
        backups_with_new_tasks.each { |backup| backup.disable_tasks! backup.new_tasks.keys }
        puts 'You can always add these apps later using "setup app add <app names>".'
      end
    end

    # Get the list of tasks to execute.
    # @param Hash options the options to get the tasks with.
    def get_tasks(backup_manager, options = {})
      backups = backup_manager.backups
      backups_with_new_tasks = backups.select { |backup| not backup.new_tasks.empty? }
      if options[:enable_new] != 'skip' and not backups_with_new_tasks.empty?
        prompt_to_enable_new_tasks backups_with_new_tasks, options
      end
      backups.map(&:tasks_to_run).map(&:values).flatten
    end

    # Runs tasks while showing the progress bar.
    def run_tasks_with_progress(tasks, name, &task_proc)
      return if tasks.empty?

      puts name
      pb = ProgressBar.create total: tasks.length, starting_at: 0, autostart: false, autofinish: false
      tasks.each do |task|
        task_info_list = task.info.compact
        pb.title = task.name
        pb.increment
        task_proc.call(task)

        # Print summary.
        pb.clear
        # print "#{task.name}: "
        task_info_list.each do |info|
          # print "#{info.status} "
        end
        # puts ''
      end
      pb.finish
      # puts "Finished #{name}"
    end
  end

  # TODO(drognanar): how to allow the --dry option for this command?
  desc 'init [<backups>...]', 'Initializes backups'
  option 'dir', type: :string
  option 'dry', type: :boolean
  option 'config', type: :string
  option 'enable_new', type: :string, default: 'prompt'
  def init(*backup_strs)
    backup_strs = [Setup::Backup::DEFAULT_BACKUP_DIR] if backup_strs.empty?

    with_backup_manager do |backup_manager|
      puts 'Creating backups:'
      backup_strs
        .map { |backup_str| Backup::resolve_backup(backup_str, options) }
        .each { |backup| backup_manager.create_backup!(backup) }

      puts 'Syncing new backups:'
      if not options[:dry]
        restore
        backup
      end
    end
  end

  desc 'backup', 'Backup your settings'
  option 'dry', type: :boolean, default: false
  option 'config', type: :string
  option 'enable_new', type: :string, default: 'prompt'
  def backup
    with_backup_manager do |backup_manager|
      run_tasks_with_progress(get_tasks(backup_manager, options), 'Backup') { |task| task.backup! }
    end
  end

  desc 'restore', 'Restore your settings'
  option 'dry', type: :boolean, default: false
  option 'config', type: :string
  option 'enable_new', type: :string, default: 'prompt'
  def restore
    with_backup_manager do |backup_manager|
      run_tasks_with_progress(get_tasks(backup_manager, options), 'Restore') { |task| task.restore! }
    end
  end

  # TODO(drognanar): include untracked files. Glob through the backup directory.
  # TODO(drognanar): tasks should return files that should be present in backup and the old backups.
  # TODO(drognanar): anything else if an untracked file.
  desc 'cleanup', 'Cleans up previous backups'
  option 'confirm', type: :boolean, default: true
  option 'dry', type: :boolean, default: false
  option 'config', type: :string
  def cleanup
    with_backup_manager do |backup_manager|
      cleanup_files_per_task = get_tasks(backup_manager, options.merge(enable_new: 'skip'))
        .map { |task| [task, task.cleanup] }
        .to_h
        .select { |task, files| not files.empty? }
      return if cleanup_files_per_task.empty?

      if options[:confirm]
        cleanup_files_per_task.each do |task, cleanup_files|
          puts "#{task.name}:"
          puts cleanup_files.join(' ')
        end

        confirm = Commandline.agree('Do you want to cleanup these files?')
      else
        confirm = true
      end

      return unless confirm
      cleanup_files_per_task.values.each { |file| (get_io options).rm_rf file }
    end
  end

  # TODO(drognanar): improve status information.
  desc 'status', 'Returns the sync status'
  def status
    with_backup_manager do |backup_manager|
      get_tasks(backup_manager, options).each {|task| puts "#{task.name}: " + task.info.map(&:status).map(&:to_s).join(' ') }
    end
  end

  desc 'app <subcommand> ...ARGS', 'Add/remove applications to be backed up.'
  subcommand 'app', AppCLI
end

end # module Cli
end # module Setup
