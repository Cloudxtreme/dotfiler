require 'setup/backups'
require 'setup/io'
require 'setup/logging'

require 'highline'
require 'ruby-progressbar'
require 'thor'

# TODO(drognanar): perhaps get rid of the progressbar and just print output directory to stdout.
# TODO(drognanar): and make it quite verbose by default.
# TODO(drognanar): possibly s/app/package
# TODO(drognanar): Possibly remove old io capture mechanism

module Setup
module Cli

Commandline = HighLine.new

module CliHelpers
  def get_io(options)
    options[:dry] ? DRY_IO : CONCRETE_IO
  end

  def get_logger_level(options = {})
    options[:verbose] ? :verbose : :info
  end

  def with_backup_manager(options = {})
    set_logger_level(get_logger_level options)
    @logger = Logging.logger['Setup::CLI']
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
    
    def summarize_task_info(task, verbose)
      sync_items = task.sync_items
      sync_items_info = sync_items.map do |sync_item, sync_item_options|
        sync_item_info = sync_item.info sync_item_options
        [sync_item_info, sync_item_options]
      end
      sync_items_groups = sync_items_info.group_by { |sync_item, _| sync_item.status }
      
      if verbose
        sync_items_groups.values.flatten(1).each do |sync_item, sync_item_options|
          level, summary, detail = summarize_sync_item_info sync_item, sync_item_options
          padded_summary = '%-11s' % "#{summary}:"
          name = "#{task.name}:#{sync_item_options[:name]}"
          @logger.send(level, [padded_summary, name, detail].compact.join(' '))
        end
      elsif sync_items_groups.keys.length == 1 and sync_items_groups.key? :up_to_date
        @logger.success("#{task.name}: all up to date")
      else
        up_to_date = sync_items_groups.fetch(:up_to_date, []).length
        resync = sync_items_groups.fetch(:sync, []).length + sync_items_groups.fetch(:resync, []).length
        overwrite = sync_items_groups.fetch(:overwrite_data, []).length
        error = sync_items_groups.fetch(:error, []).length

        summary = []
        summary << "up to date: #{up_to_date}" if up_to_date > 0
        summary << "to sync: #{resync}" if resync > 0
        summary << "items differ: #{overwrite}" if overwrite > 0
        summary << "error: #{error}" if error > 0
        
        @logger.info("#{task.name}: #{summary.join(', ')}")
      end
    end
    
    def summarize_sync_item_info(sync_item_info, sync_item_options)
      case sync_item_info.status
      when :error then [:error, 'error', sync_item_info.errors]
      when :up_to_date then [:success, "up-to-date", nil]
      when :sync, :resync then [:info, "needs sync", nil]
      when :overwrite_data then [:warn, "differs", nil]
      end
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
  option 'verbose', type: :boolean
  def init(*backup_strs)
    backup_strs = [Setup::Backup::DEFAULT_BACKUP_DIR] if backup_strs.empty?

    with_backup_manager do |backup_manager|
      puts 'Creating backups:'
      backup_strs
        .map { |backup_str| Backup::resolve_backup(backup_str, options) }
        .each { |backup| backup_manager.create_backup!(backup) }

      puts 'Syncing new backups:'
      if not options[:dry]
        backup_manager.load_backups!
        # TODO(drognanar): Print status per line.
        run_tasks_with_progress(get_tasks(backup_manager, options), 'Sync') { |task| task.sync! }
      end
    end
  end

  desc 'backup', 'Backup your settings'
  option 'dry', type: :boolean, default: false
  option 'config', type: :string
  option 'enable_new', type: :string, default: 'prompt'
  option 'verbose', type: :boolean
  def backup
    with_backup_manager do |backup_manager|
      run_tasks_with_progress(get_tasks(backup_manager, options), 'Backup') { |task| task.backup! }
    end
  end

  desc 'restore', 'Restore your settings'
  option 'dry', type: :boolean, default: false
  option 'config', type: :string
  option 'enable_new', type: :string, default: 'prompt'
  option 'verbose', type: :boolean
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
  option 'untracked', type: :boolean
  def cleanup
    with_backup_manager do |backup_manager|
      cleanup_files_per_task = get_tasks(backup_manager, options.merge(enable_new: 'skip'))
        .map { |task| [task, task.cleanup] }
        .to_h
        .select { |task, files| not files.empty? }
      return true if cleanup_files_per_task.empty?

      if options[:confirm]
        cleanup_files_per_task.each do |task, cleanup_files|
          puts "#{task.name}:"
          puts cleanup_files.join(' ')
        end

        confirm = Commandline.agree('Do you want to cleanup these files?')
      else
        confirm = true
      end

      return true unless confirm
      cleanup_files_per_task.values.each { |file| (get_io options).rm_rf file }
    end
  end

  desc 'status', 'Returns the sync status'
  option 'verbose', type: :boolean
  def status
    with_backup_manager do |backup_manager|
      get_tasks(backup_manager, options).each do |task|
        summarize_task_info(task, options[:verbose])
      end
    end
  end

  desc 'app <subcommand> ...ARGS', 'Add/remove applications to be backed up.'
  subcommand 'app', AppCLI
end

end # module Cli
end # module Setup
