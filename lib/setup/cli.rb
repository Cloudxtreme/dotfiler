require 'setup/backups'
require 'setup/io'
require 'setup/logging'

require 'highline'
require 'thor'
require 'yaml'

module Setup::Cli

class CommonCLI < Thor
  class_option 'help', type: :boolean, desc: 'Print help for a specific command'
  class_option 'verbose', type: :boolean, desc: 'Print verbose information to stdout'

  no_commands do
    def init_command(command, options)
      return help command if options[:help]
      LOGGER.level = options[:verbose] ? :verbose : :info
      @io = options[:dry] ? Setup::DRY_IO : Setup::CONCRETE_IO
      @cli = HighLine.new

      yield Setup::BackupManager.from_config(io: @io).tap(&:load_backups!)
      return true
    rescue Setup::InvalidConfigFileError => e
      LOGGER.error "Could not load \"#{e.path}\""
      return false
    end
  end
end

class Package < CommonCLI
  desc 'add [<names>...]', 'Adds app\'s settings to the backup.'
  def add(*names)
    init_command(:add, options) do |backup_manager|
      backup_manager.backups.map { |backup| backup.enable_tasks! names }
    end
  end

  desc 'remove [<name>...]', 'Removes app\'s settings from the backup.'
  def remove(*names)
    init_command(:remove, options) do |backup_manager|
      backup_manager.backups.map { |backup| backup.disable_tasks! names }
    end
  end

  desc 'list', 'Lists packages for which settings can be backed up.'
  def list
    init_command(:list, options) do |backup_manager|
      backup_manager.backups.each do |backup|
        LOGGER << "backup #{backup.backup_path}:\n\n" if backup_manager.backups.length > 1
        LOGGER << "Enabled packages:\n"
        LOGGER << backup.enabled_task_names.to_a.join(', ') + "\n\n"
        LOGGER << "Disabled packages:\n"
        LOGGER << backup.disabled_task_names.to_a.join(', ') + "\n\n"
        LOGGER << "New packages:\n"
        LOGGER << backup.new_tasks.keys.join(', ') + "\n"
      end
    end
  end

  desc 'edit NAME', 'Edit an existing package.'
  option 'global'
  def edit(name)
    init_command(:edit, options) do |backup_manager|
      packages_dir = options[:global] ? Setup::Backup::APPLICATIONS_DIR : backup_manager.backups[0].backup_tasks_path
      task_path = File.join packages_dir, "#{name}.yml"

      if not File.exist? task_path
        default_package_content = YAML::dump({ name: name.capitalize, root: '~/', files: [] })
        File.write task_path, default_package_content if not File.exist? task_path
      end

      editor = ENV['editor'] || 'vim'
      @io.system("#{editor} #{task_path}")
    end
  end
end

class Program < CommonCLI
  no_commands do
    def self.sync_options
      option 'dry', type: :boolean, default: false, desc: 'Print operations that would be executed by setup.'
      option 'enable_new', type: :string, default: 'prompt', desc: 'Find new packages to enable.'
      option 'copy', type: :boolean, default: false, desc: 'Copy files instead of symlinking them.'
    end

    # Prompts to enable new tasks.
    def prompt_to_enable_new_tasks(backups_with_new_tasks, options)
      if options[:enable_new] == 'prompt'
        LOGGER << "Found new packages to sync:\n\n"
        backups_with_new_tasks.each do |backup|
          LOGGER << backup.backup_path + "\n"
          LOGGER << backup.new_tasks.keys.join(' ') + "\n"
        end
      end

      # TODO(drognanar): Allow to specify the list of applications?
      # TODO(drognanar): How to handle multiple backups? Give the prompt per backup directory?
      prompt_accept = (options[:enable_new] == 'prompt' and @cli.agree('Backup all of these applications? [y/n]'))
      if options[:enable_new] == 'all' or prompt_accept
        backups_with_new_tasks.each { |backup| backup.enable_tasks! backup.new_tasks.keys }
      else
        backups_with_new_tasks.each { |backup| backup.disable_tasks! backup.new_tasks.keys }
        LOGGER.warn 'You can always add these apps later using "setup app add <app names>"'
      end
    end

    # Get the list of tasks to execute.
    # @param Hash options the options to get the tasks with.
    def get_tasks(backup_manager, options = {})
      # TODO(drognanar): Perhaps move discovery outside?
      # TODO(drognanar): Only discover on init/discover/update?
      backups = backup_manager.backups
      backups_with_new_tasks = backups.select { |backup| not backup.new_tasks.empty? }
      if options[:enable_new] != 'skip' and not backups_with_new_tasks.empty?
        prompt_to_enable_new_tasks backups_with_new_tasks, options
      end
      backups.map(&:tasks_to_run).map(&:values).flatten
    end

    def summarize_task_info(task)
      sync_items_info = task.sync_items.map do |sync_item, sync_item_options|
        sync_item_info = sync_item.info sync_item_options
        [sync_item_info, sync_item_options]
      end
      sync_items_groups = sync_items_info.group_by { |sync_item, _| sync_item.status }

      if not options[:verbose] and sync_items_groups.keys.length == 1 and sync_items_groups.key? :up_to_date
        LOGGER << "up-to-date: #{task.name}\n"
      else
        sync_items_groups.values.flatten(1).each do |sync_item, sync_item_options|
          summary, detail = summarize_sync_item_info sync_item
          padded_summary = '%-11s' % "#{summary}:"
          name = "#{task.name}:#{sync_item_options[:name]}"
          LOGGER << [padded_summary, name, detail].compact.join(' ') + "\n"
        end
      end
    end

    def summarize_sync_item_info(sync_item_info)
      case sync_item_info.status
      when :error then ['error', sync_item_info.errors]
      when :up_to_date then ['up-to-date', nil]
      when :backup, :restore, :resync then ['needs sync', nil]
      when :overwrite_data then ['differs', nil]
      end
    end

    def ask_overwrite(backup_path, restore_path)
      # TODO(drognanar): Persist answers (ba) and (br).
      LOGGER.warn "Needs to overwrite a file"
      LOGGER.warn "Backup: \"#{backup_path}\""
      LOGGER.warn "Restore: \"#{restore_path}\""
      @cli.choose do |menu|
        menu.prompt = "Keep back up, restore, back up for all, restore for all?"
        menu.choice(:b) { return :backup }
        menu.choice(:r) { return :restore }
        menu.choice(:ba) { return :backup }
        menu.choice(:br) { return :restore }
      end
    end

    # Runs tasks while showing the progress bar.
    def run_tasks_with_progress(backup_manager)
      tasks = get_tasks(backup_manager, options)
      if tasks.empty?
        LOGGER << "Nothing to sync\n"
        return true
      end

      log_sync_item = proc { |sync_item_options| LOGGER.info "Syncing #{sync_item_options[:name]}" }
      LOGGER << "Syncing:\n"
      tasks.each do |task|
        LOGGER.info "Syncing package #{task.name}:"
        task.sync! copy: options[:copy], on_overwrite: method(:ask_overwrite), &log_sync_item
      end
    end
  end

  desc 'init [<backups>...]', 'Initializes backups'
  option 'dir', type: :string
  option 'sync', type: :boolean, default: true
  option 'force', type: :boolean
  Program.sync_options
  def init(*backup_strs)
    backup_strs = [Setup::Backup::DEFAULT_BACKUP_DIR] if backup_strs.empty?

    init_command(:init, options) do |backup_manager|
      LOGGER << "Creating backups:\n"
      backup_strs
        .map { |backup_str| Setup::Backup::resolve_backup(backup_str, backup_dir: options[:dir]) }
        .each { |backup| backup_manager.create_backup!(backup, force: options[:force]) }

      # Cannot run sync in dry mode since the backup creation was run in dry mode.
      if not options[:dry] and options[:sync]
        backup_manager.tap(&:load_backups!).tap(&method(:run_tasks_with_progress))
      end
    end
  end

  desc 'sync', 'Synchronize your settings'
  Program.sync_options
  def sync
    init_command(:symc, options, &method(:run_tasks_with_progress))
  end

  desc 'cleanup', 'Cleans up previous backups'
  option 'confirm', type: :boolean, default: true
  option 'dry', type: :boolean, default: false
  option 'untracked', type: :boolean
  def cleanup
    init_command(:cleanup, options) do |backup_manager|
      tasks = get_tasks(backup_manager, options.merge(enable_new: 'skip'))
      cleanup_files = tasks.map { |task| task.cleanup untracked: options[:untracked] }.flatten(1)

      if cleanup_files.empty?
        LOGGER << "Nothing to clean.\n"
      end

      cleanup_files.each do |file|
        LOGGER << "Deleting \"#{file}\"\n"
        confirmed = (not options[:confirm] or @cli.agree('Do you want to remove this file? [y/n]'))
        @io.rm_rf file if confirmed
      end
    end
  end

  desc 'status', 'Returns the sync status'
  def status
    init_command(:status, options) do |backup_manager|
      tasks = get_tasks(backup_manager, options)
      if tasks.empty?
        LOGGER.warn "No packages enabled."
        LOGGER.warn "Use ./setup package add to enable packages."
      else
        LOGGER << "Current status:\n\n"
        tasks.each(&method(:summarize_task_info))
      end
    end
  end

  desc 'package <subcommand> ...ARGS', 'Add/remove packages to be backed up'
  subcommand 'package', Package
end

end # module Setup::Cli
