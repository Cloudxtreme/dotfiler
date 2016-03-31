require 'setup/backups'
require 'setup/io'
require 'setup/logging'

require 'highline'
require 'thor'

module Setup::Cli

# TODO(drognanar): use Thor to ask questions?
# TODO(drognanar): Get rid of `highline`?
# TODO(drognanar): Try to check thor's status messages.
# TODO(drognanar): Add package new/edit methods to quickly edit and create new packages.

Commandline = HighLine.new

module CliHelpers
  def get_io(options)
    options[:dry] ? Setup::DRY_IO : Setup::CONCRETE_IO
  end

  def with_backup_manager(options)
    LOGGER.level = options[:verbose] ? :verbose : :info
    dry = options[:dry] || false
    @io = get_io(options)
    config = { io: @io, dry: dry }
    yield Setup::BackupManager.from_config(config).tap(&:load_backups!)
    return true
  rescue Setup::InvalidConfigFileError => e
    LOGGER.error "An error occured while trying to load \"#{e.path}\""
    return false
  end
end

class PackageCLI < Thor
  no_commands do
    include CliHelpers
  end

  class_option 'help', type: :boolean

  desc 'add [<names>...]', 'Adds app\'s settings to the backup.'
  def add(*names)
    return help :add if options[:help]
    with_backup_manager(options) do |backup_manager|
      backup_manager.backups.map { |backup| backup.enable_tasks! names }
    end
  end

  desc 'remove [<name>...]', 'Removes app\'s settings from the backup.'
  def remove(*names)
    return help :remove if options[:help]
    with_backup_manager(options) do |backup_manager|
      backup_manager.backups.map { |backup| backup.disable_tasks! names }
    end
  end

  desc 'list', 'Lists packages for which settings can be backed up.'
  def list
    return help :list if options[:help]
    with_backup_manager(options) do |backup_manager|
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

  desc 'new', 'Create a new package.'
  option 'local'
  def new
  end

  desc 'edit', 'Edit an existing package.'
  option 'local'
  def edit
  end
end

class SetupCLI < Thor
  no_commands do
    include CliHelpers

    def self.common_options
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
      prompt_accept = (options[:enable_new] == 'prompt' and Commandline.agree('Backup all of these applications? [y/n]'))
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

    # Runs tasks while showing the progress bar.
    def run_tasks_with_progress(action, title: '', empty: '')
      with_backup_manager(options) do |backup_manager|
        tasks = get_tasks(backup_manager, options)
        if tasks.empty?
          LOGGER << "#{empty}\n"
          return true
        end

        LOGGER << "#{title}:\n"
        tasks.each do |task|
          LOGGER.info "#{title} package #{task.name}:"
          task.send(action, copy: options[:copy]) { |sync_item_options| LOGGER.info "#{title} #{sync_item_options[:name]}" }
        end
      end
    end
  end

  class_option 'help', type: :boolean, desc: 'Print help for a specific command'
  class_option 'verbose', type: :boolean, desc: 'Print verbose information to stdout'

  desc 'init [<backups>...]', 'Initializes backups'
  option 'dir', type: :string
  option 'sync', type: :boolean, default: true
  option 'force', type: :boolean
  SetupCLI.common_options
  def init(*backup_strs)
    return help :init if options[:help]
    backup_strs = [Setup::Backup::DEFAULT_BACKUP_DIR] if backup_strs.empty?

    with_backup_manager(options) do |backup_manager|
      LOGGER << "Creating backups:\n"
      backup_strs
        .map { |backup_str| Setup::Backup::resolve_backup(backup_str, backup_dir: options[:dir]) }
        .each { |backup| backup_manager.create_backup!(backup, force: options[:force]) }

      # Cannot run sync in dry mode since the backup creation was run in dry mode.
      if not options[:dry] and options[:sync]
        run_tasks_with_progress(:sync!, title: "Syncing", empty: 'Nothing to sync')
      end
    end
  end

  desc 'backup', 'Backup your settings'
  SetupCLI.common_options
  def backup
    return help :backup if options[:help]
    run_tasks_with_progress(:backup!, title: 'Backing up', empty: 'Nothing to back up')
  end

  desc 'restore', 'Restore your settings'
  SetupCLI.common_options
  def restore
    return help :restore if options[:help]
    run_tasks_with_progress(:restore!, title: 'Restoring', empty: 'Nothing to restore')
  end

  desc 'cleanup', 'Cleans up previous backups'
  option 'confirm', type: :boolean, default: true
  option 'dry', type: :boolean, default: false
  option 'untracked', type: :boolean
  def cleanup
    return help :cleanup if options[:help]
    with_backup_manager(options) do |backup_manager|
      tasks = get_tasks(backup_manager, options.merge(enable_new: 'skip'))
      cleanup_files = tasks.map { |task| task.cleanup untracked: options[:untracked] }.flatten(1)

      if cleanup_files.empty?
        LOGGER << "Nothing to clean.\n"
      end

      cleanup_files.each do |file|
        LOGGER << "Deleting \"#{file}\"\n"
        confirmed = (not options[:confirm] or Commandline.agree('Do you want to remove this file? [y/n]'))
        @io.rm_rf file if confirmed
      end
    end
  end

  desc 'status', 'Returns the sync status'
  def status
    return help :status if options[:help]
    with_backup_manager(options) do |backup_manager|
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
  subcommand 'package', PackageCLI
end

end # module Setup::Cli
