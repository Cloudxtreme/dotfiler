require 'setup/io'
require 'setup/backups'

require 'highline'
require 'ruby-progressbar'
require 'thor'

# TODO: improve summary output per task

module Setup
module Cli

DEFAULT_BACKUP_ROOT = File.expand_path "~/dotfiles/home_profile"
DEFAULT_OPTIONS = { dry: false }
Commandline = HighLine.new

class AppCLI < Thor
  desc 'add [<names>...]', 'Adds app\' settings to the backup.'
  def add(*names)
    Setup::backups_add_tasks names
  end

  desc 'remove [<name>...]', 'Removes app\'s settings from the backup.'
  def remove(*names)
    Setup::backups_remove_tasks names
  end

  desc 'list', 'Lists apps for which settings can be backed up.'
  def list
    Setup::backups_print_new_tasks
  end
end

class SetupCLI < Thor
  no_commands {
    def get_io(options = {})
      options[:dry] ? DRY_IO : CONCRETE_IO
    end

    # Get the list of tasks to execute.
    # @param Hash options the options to get the tasks with.
    def get_tasks(options = {})
      options = DEFAULT_OPTIONS.merge options
      backups = Setup::get_backups (get_io options)
      unless options[:skip_new_tasks]
        Setup::classify_new_tasks(backups) { Commandline.agree 'Backup all of these applications? [y/n]' }
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

    def resolve_backup(backup_str, options)
      # TODO: resolve the path.
      # TODO: implement.
      # TODO: how to interpret the path (download url/location on disk)?
      # TODO: I don't know
    end

    def resolve_backups(backup_strs, options)
      # TODO: case no backup_strs
      # TODO: case when only one backup_str given
      # TODO: case when multiple backup_strs given
      backup_strs.map { |backup_str| resolve_backup(backup_str, options) }
    end
  }

  desc 'init [<backups>...]', 'Initializes backups'
  option 'dir', :type => :string, :default => ''
  def init(*backups)
    init_backups resolve_backups(backup_str, options)
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
    # TODO: include untracked files.
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
