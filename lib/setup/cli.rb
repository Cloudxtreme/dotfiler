require 'setup/backups'
require 'setup/extend/tasks'
require 'setup/package_template'
require 'setup/reporter'
require 'setup/sync_context'

require 'highline'
require 'thor'
require 'yaml'

module Setup::Cli

class CommonCLI < Thor
  class_option 'help', type: :boolean, desc: 'Print help for a specific command'
  class_option 'verbose', type: :boolean, desc: 'Print verbose information to stdout'

  attr_reader :backup_manager

  def initialize(args = [], opts = {}, config = {})
    super
    backup_dir = config[:dir] || Dir.pwd
    LOGGER.level = options[:verbose] ? :verbose : :info
    @cli = HighLine.new
    @ctx = get_context(options).with_backup_dir(backup_dir).add_default_applications
    @backup_manager = get_backup_manager config
  end

  no_commands do
    def get_backup_manager(config)
      package_constructor = config[:package]

      if package_constructor.is_a? Class then package_constructor.new @ctx
      elsif package_constructor.is_a? Proc then package_constructor.call @ctx
      else Setup::BackupManager.from_config(@ctx)
      end
    end

    def backups_file_path
      @ctx.backup_path 'backups.rb'
    end

    def init_backup_manager
      @backup_manager.load_backups! if @backup_manager.respond_to? :load_backups!
      return true
    rescue Setup::InvalidConfigFileError => e
      LOGGER.error "Could not load \"#{e.path}\": #{e.inner_exception}"
      return false
    end
  end
end

class Package < CommonCLI
  no_commands do
    def get_context(options)
      Setup::SyncContext.new copy: options[:copy], untracked: options[:untracked], reporter: Setup::LoggerReporter.new(LOGGER), logger: LOGGER
    end
  end

  desc 'new <name>', 'Create a package with a given name'
  option 'force', type: :boolean
  def new(name_str)
    return help :new if options[:help]
    return false unless init_backup_manager and @ctx.io.exist? backups_file_path

    dir = File.dirname name_str
    if dir == '.'
      packages_dir = @ctx.backup_path "_packages"
      package_path = File.join(packages_dir, "#{name_str}.rb")
      name = name_str
    else
      package_path = @ctx.backup_path(name_str)
      packages_dir = File.dirname package_path
      name = File.basename name_str, '.*'
    end

    LOGGER << "Creating a package\n"

    if File.exist?(package_path) and not options[:force]
      LOGGER.warn "Package already exists"
    else
      @ctx.io.mkdir_p File.dirname package_path
      @ctx.io.write package_path, Setup::Templates::package(name, [])
    end

    backups_file = @ctx.io.read backups_file_path
    step = "yield package_from_files #{File.join(packages_dir, '*.rb')}"
    backups_file = Setup::Edits::AddStep.new('MyBackup', step).rewrite_str backups_file
    @ctx.io.write backups_file_path, backups_file
  end

  desc 'add [<names>...]', 'Adds app\'s settings to the backup.'
  def add(*names)
    return help :add if options[:help]
    return false unless init_backup_manager and @ctx.io.exist? backups_file_path
    backups_file = @ctx.io.read backups_file_path
    names.each do |name|
      if @backup_manager.package(name).nil?
        LOGGER.error "Package #{name} not found"
      else
        backups_file = Setup::Edits::AddStep.new('MyBackup', "yield package '#{name}'").rewrite_str backups_file
      end
    end
    @ctx.io.write backups_file_path, backups_file
  end

  desc 'remove [<name>...]', 'Removes app\'s settings from the backup.'
  def remove(*names)
    return help :remove if options[:help]
    return false unless init_backup_manager and @ctx.io.exist? backups_file_path
    backups_file = @ctx.io.read backups_file_path
    names.each do |name|
      if Setup::Backups::find_package(@backup_manager, name).nil?
        LOGGER.error "Package #{name} not found"
      else
        backups_file = Setup::Edits::RemoveStep.new('MyBackup', "yield package '#{name}'").rewrite_str backups_file
      end
    end
    @ctx.io.write backups_file_path, backups_file
  end

  desc 'list', 'Lists packages for which settings can be backed up.'
  def list
    return help :list if options[:help]
    return false unless init_backup_manager
    @ctx.logger << "Packages:\n"
    @ctx.logger << Setup::Status::print_nested(@backup_manager) { |item| [item.name, item.entries.select(&:children?)] }
  end

  desc 'edit NAME', 'Edit an existing package.'
  def edit(name)
    return help :edit if options[:help]
    return false unless init_backup_manager

    package = Setup::Backups::find_package @backup_manager, name
    if package.nil? or Setup::Backups::get_source(package).nil?
      @ctx.logger.warn "Could not find a package to edit. It might not have been added"
    else
      Setup::Backups::edit_package package, @ctx.io
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

    def get_context(options)
      Setup::SyncContext.new copy: options[:copy], untracked: options[:untracked], on_overwrite: method(:ask_overwrite), on_delete: method(:ask_delete), reporter: Setup::LoggerReporter.new(LOGGER), logger: LOGGER
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

    def ask_delete(file)
      LOGGER << "Deleting \"#{file}\"\n"
      (not options[:confirm] or @cli.agree('Do you want to remove this file? [y/n]'))
    end

    # Prompts to enable new packages.
    def prompt_to_enable_new_packages(backup_manager, options)
      backups_with_new_packages = {}
      backup_manager.each do |backup|
        discovered_packages = backup.discover_packages
        backups_with_new_packages[backup] = discovered_packages unless discovered_packages.empty?
      end

      if backups_with_new_packages.empty?
        return
      end

      if options[:enable_new] == 'prompt'
        LOGGER << "Found new packages to sync:\n\n"
        backups_with_new_packages.each do |backup, discovered_packages|
          LOGGER << backup.ctx.backup_path + "\n"
          LOGGER << discovered_packages.map { |package| package.name }.join(' ') + "\n"
        end
      end

      # TODO(drognanar): Do not actually update the backup here
      # TODO(drognanar): Allow to specify the list of applications?
      # TODO(drognanar): How to handle multiple backups? Give the prompt per backup directory?
      prompt_accept = (options[:enable_new] == 'prompt' and @cli.agree('Backup all of these applications? [y/n]'))
      if options[:enable_new] == 'all' or prompt_accept
        backups_with_new_packages.each do |backup, discovered_packages|
          backup.items += discovered_packages
          backup.update_applications_file
        end
      end
    end
  end

  desc 'init [<backups>...]', 'Initializes backups'
  option 'dir', type: :string
  option 'force', type: :boolean
  Program.sync_options
  def init(path = '')
    return help :init if options[:help]
    return false unless init_backup_manager
    Setup::Backups::create_backup @ctx.backup_path(path), @ctx.logger, @ctx.io, force: options[:force]
  end

  # TODO(drognanar): Move discovery to package CLI
  desc 'discover', 'Discovers applications'
  option 'enable_new', type: :string, default: 'prompt', desc: 'Find new packages to enable.'
  def discover
    return help :discover if options[:help]
    return false unless init_backup_manager

    @backup_manager.load_backups!
    prompt_to_enable_new_packages @backup_manager, options
  end

  desc 'sync', 'Synchronize your settings'
  Program.sync_options
  def sync
    return help :sync if options[:help]
    return false unless init_backup_manager
    @ctx.logger << "Syncing:\n"
    @backup_manager.sync!
    @ctx.logger << "Nothing to sync\n" if @ctx.reporter.events.empty?
  end

  desc 'cleanup', 'Cleans up previous backups'
  option 'confirm', type: :boolean, default: true
  option 'dry', type: :boolean, default: false
  option 'untracked', type: :boolean
  def cleanup
    return help :cleanup if options[:help]
    return false unless init_backup_manager
    @backup_manager.cleanup!
    if @ctx.reporter.events(:delete).empty?
      @ctx.logger << "Nothing to clean.\n"
    end
  end

  desc 'status', 'Returns the sync status'
  def status
    return help :status if options[:help]
    return false unless init_backup_manager
    @ctx.logger << "Current status:\n\n"
    status = @backup_manager.status
    if status.name.empty? and status.items.empty?
      @ctx.logger.warn "No packages enabled."
      @ctx.logger.warn "Use ./setup package add to enable packages."
    else
      @ctx.logger << Setup::Status::get_status_str(status)
    end
  end

  desc 'package <subcommand> ...ARGS', 'Add/remove packages to be backed up'
  subcommand 'package', Package
end

end # module Setup::Cli
