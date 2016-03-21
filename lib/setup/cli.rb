require 'setup/io'
require 'setup/backups'

require 'highline'
require 'ruby-progressbar'
require 'thor'

# TODO: improve summary output per task
# TODO: make this more output friendly.
# TODO: perhaps get rid of the progressbar and just print output directory to stdout.
# TODO: and make it quite verbose by default.

module Setup
module Cli

Commandline = HighLine.new

class AppCLI < Thor
  no_commands {
    def get_io(options = {})
      options[:dry] ? DRY_IO : CONCRETE_IO
    end

    def get_backups_manager(options = {})
      Setup::BackupManager.new io: get_io(options), config_path: options[:config]
    end
  }

  desc 'add [<names>...]', 'Adds app\'s settings to the backup.'
  option 'config', type: :string
  def add(*names)
    get_backups_manager(options).get_backups.map { |backup| backup.enable_tasks names }
  end

  desc 'remove [<name>...]', 'Removes app\'s settings from the backup.'
  option 'config', type: :string
  def remove(*names)
    get_backups_manager(options).get_backups.map { |backup| backup.disable_tasks names }
  end

  desc 'list', 'Lists apps for which settings can be backed up.'
  option 'config', type: :string
  def list
    backups = get_backups_manager(options).get_backups
    # TODO: Print all tasks (enabled/diabled/new)
    Setup::print_new_tasks get_backups_manager(options).new_backup_tasks
  end
end

class SetupCLI < Thor
  no_commands {
    def get_io(options = {})
      options[:dry] ? DRY_IO : CONCRETE_IO
    end

    def get_backups_manager(options = {})
      Setup::BackupManager.new io: get_io(options), config_path: options[:config]
    end

    # Prompts to enable new tasks.
    def prompt_to_enable_new_tasks(backups_with_new_tasks, options)
      puts 'These applications can be backed up:'
      backups_with_new_tasks.each do |backup|
        puts backup.backup_path
        puts backup.new_tasks.keys.join(' ')
      end

      # TODO: validate json schemas
      prompt_accept = (options[:enable_new] == 'prompt' and Commandline.agree('Backup all of these applications? [y/n]'))
      if options[:enable_new] == 'all' or prompt_accept
        backups_with_new_tasks.each { |backup| backup.enable_tasks backup.new_tasks.keys }
      else
        backups_with_new_tasks.each { |backup| backup.disable_tasks backup.new_tasks.keys }
        puts 'You can always add these apps later using "setup app add <app names>".'
      end
    end

    # Get the list of tasks to execute.
    # @param Hash options the options to get the tasks with.
    def get_tasks(options = {})
      backups = get_backups_manager(options).get_backups
      backups_with_new_tasks = backups.select { |backup| not backup.new_tasks.empty? }
      if not backups_with_new_tasks.empty? and not options[:skip_new_tasks]
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
        pb.title = task.name
        pb.increment
        task_proc.call(task)

        # Print summary.
        pb.clear
        print "#{task.name}: "
        task.info.compact.each do |info|
          print "#{info.status} "
        end
        puts ''
      end
      pb.finish
      puts "Finished #{name}"
    end
  }

  # TODO: how to allow the --dry option for this command?
  desc 'init [<backups>...]', 'Initializes backups'
  option 'dir', type: :string
  option 'config', type: :string
  option 'enable_new', type: :string, default: 'prompt'
  def init(*backup_strs)
    backup_strs = [Setup::Backup::DEFAULT_BACKUP_DIR] if backup_strs.empty?

    backup_manager = get_backups_manager(options)
    backup_strs.map { |backup_str| Backup::resolve_backup(backup_str, options) }
      .each { |backup| backup_manager.create_backup(backup) }

    if not options[:dry]
      restore
      backup
    end
  end

  desc 'backup', 'Backup your settings'
  option 'dry', type: :boolean, default: false
  option 'config', type: :string
  def backup
    run_tasks_with_progress(get_tasks(options), 'Backup') { |task| task.backup! }
  end

  desc 'restore', 'Restore your settings'
  option 'dry', type: :boolean, default: false
  option 'config', type: :string
  def restore
    run_tasks_with_progress(get_tasks(options), 'Restore') { |task| task.restore! }
  end

  # TODO: include untracked files. Glob through the backup directory.
  desc 'cleanup', 'Cleans up previous backups'
  option 'confirm', type: :boolean, default: true
  option 'dry', type: :boolean, default: :false
  option 'config', type: :string
  def cleanup
    cleanup_files_per_task = get_tasks.map { |task| [task, task.cleanup] }.to_h
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
    cleanup_files_per_task.values.each { |file| (get_io options).rm file }
  end

  desc 'status', 'Returns the sync status'
  def status
    get_tasks.each {|task| puts "#{task.name}: " + task.info.map(&:status).map(&:to_s).join(' ') }
  end

  desc 'app <subcommand> ...ARGS', 'Add/remove applications to be backed up.'
  subcommand 'app', AppCLI
end

end # module Cli
end # module Setup
