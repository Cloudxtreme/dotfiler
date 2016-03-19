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
      Setup::BackupManager.new io: get_io(options)
    end
  }
  
  desc 'add [<names>...]', 'Adds app\'s settings to the backup.'
  def add(*names)
    get_backups_manager(options).get_backups.map { |backup| backup.enable_tasks names }
  end

  desc 'remove [<name>...]', 'Removes app\'s settings from the backup.'
  def remove(*names)
    get_backups_manager(options).get_backups.map { |backup| backup.disable_tasks names }
  end

  desc 'list', 'Lists apps for which settings can be backed up.'
  def list
    get_backups_manager(options).backups_print_new_tasks
  end
end

class SetupCLI < Thor
  no_commands {
    DEFAULT_BACKUP_ROOT = File.expand_path '~/dotfiles/local'
    
    def get_io(options = {})
      options[:dry] ? DRY_IO : CONCRETE_IO
    end
    
    def get_backups_manager(options = {})
      Setup::BackupManager.new io: get_io(options)
    end

    # Get the list of tasks to execute.
    # @param Hash options the options to get the tasks with.
    def get_tasks(options = {})
      backups_manager = get_backups_manager(options)
      backups = backups_manager.get_backups
      unless options[:skip_new_tasks]
        backups_manager.classify_new_tasks(backups) { Commandline.agree 'Backup all of these applications? [y/n]' }
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

  desc 'init [<backups>...]', 'Initializes backups'
  option 'dir', :type => :string, :default => ''
  def init(*backup_strs)
    backup_strs = [SetupCLI.DEFAULT_BACKUP_ROOT] if backup_strs.empty?
    
    backup_manager = get_backups_manager(options)
    backup_strs.map { |backup_str| Backup::resolve_backup(backup_str, options) }
      .each &backup_manager.method(:create_backup)

    restore
    backup
  end

  desc 'backup', 'Backup your settings'
  option 'dry', :type => :boolean, :default => false
  def backup
    run_tasks_with_progress(get_tasks(options), 'Backup') { |task| task.backup! }
  end

  desc 'restore', 'Restore your settings'
  option 'dry', :type => :boolean, :default => false
  def restore
    run_tasks_with_progress(get_tasks(options), 'Restore') { |task| task.restore! }
  end

  desc 'cleanup', 'Cleans up previous backups'
  option 'confirm', :type => :boolean, :default => false
  option 'dry', :type => :boolean, :default => :false
  def cleanup
    # TODO: include untracked files. Glob through the backup directory.
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
