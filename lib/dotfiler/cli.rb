require 'dotfiler/sync_utils'
require 'dotfiler/extend/task_utils'
require 'dotfiler/templates'
require 'dotfiler/reporter'
require 'dotfiler/sync_context'

require 'highline'
require 'thor'
require 'yaml'

module Dotfiler
  module Cli
    # @api private
    # Abstract class that provides common options, initialization logic to the CLI classes.
    class CommonCLI < Thor
      class_option 'help', type: :boolean, desc: 'Print help for a specific command'
      class_option 'verbose', type: :boolean, desc: 'Print verbose information to stdout'

      attr_reader :backup_manager, :backups_file_path

      def initialize(args = [], opts = {}, config = {})
        super
        backup_dir = config[:dir] || Dir.pwd
        LOGGER.level = options[:verbose] ? :verbose : :info
        @cli = HighLine.new
        @ctx = get_context(options).with_backup_dir(backup_dir).add_default_applications
        @package_constructor = config[:package]
        @on_error = config[:on_error] || method(:on_error)
      end

      no_commands do
        def on_error(msg)
          LOGGER.error msg
          exit 1
        end

        def invoke_command(command, *args)
          return help command.name if options[:help]
          @backup_manager = create_backup_manager
          super
        rescue Dotfiler::TaskUtils::ImportScriptError => e
          @on_error.call "Could not load \"#{e.path}\": #{e.inner_exception}"
        end

        def create_backup_manager
          if @package_constructor.is_a? Class
            @package_constructor.new @ctx
          elsif @package_constructor.is_a? Proc
            @package_constructor.call @ctx
          elsif @package_constructor.is_a? String
            @backups_file_path = @package_constructor if File.exist? @package_constructor
            @ctx.package_from_files(@package_constructor)
          else
            @backups_file_path = @ctx.backup_path('backups.rb')
            @ctx.package_from_files(@backups_file_path)
          end
        end

        def backups_class_name
          @backup_manager.class.name.split('::').last
        end
      end
    end

    # A CLI class that performs operations on packages.
    # It modifies the +backups.rb+ file as well as lists packages.
    class Package < CommonCLI
      no_commands do
        def get_context(options)
          Dotfiler::SyncContext.new copy: options[:copy], untracked: options[:untracked], reporter: Dotfiler::LoggerReporter.new(LOGGER), logger: LOGGER, dry: options[:dry]
        end

        def create_package(package_name, package_path)
          packages_dir = File.dirname package_path
          LOGGER << "Creating a package\n"

          if File.exist?(package_path) && !options[:force]
            LOGGER.warn 'Package already exists'
          else
            @ctx.io.mkdir_p File.dirname package_path
            @ctx.io.write package_path, Dotfiler::Templates.package(package_name, files: [])
          end

          backups_file = @ctx.io.read backups_file_path
          step = "yield package_from_files #{File.join(packages_dir, '*.rb')}"
          backups_file = Dotfiler::Edits::AddStep.new(backups_class_name, step).rewrite_str backups_file
          @ctx.io.write backups_file_path, backups_file
        end
      end

      desc 'new <name>', 'Create a package with a given name'
      option 'force', type: :boolean
      def new(name_str)
        return @on_error.call 'Cannot find backup file.' unless !backups_file_path.nil? && @ctx.io.exist?(backups_file_path)

        dir = File.dirname name_str
        if dir == '.'
          packages_dir = @ctx.backup_path '_packages'
          package_path = File.join(packages_dir, "#{name_str}.rb")

          create_package name_str, package_path
        else
          package_path = @ctx.backup_path(name_str)
          package_name = File.basename name_str, '.*'

          create_package package_name, package_path
        end
      end

      desc 'add [<names>...]', 'Adds app\'s settings to the backup.'
      def add(*names)
        return @on_error.call 'Cannot find backup file.' unless !backups_file_path.nil? && @ctx.io.exist?(backups_file_path)

        backups_file = @ctx.io.read backups_file_path
        names.each do |name|
          if @backup_manager.package(name).nil?
            LOGGER.error "Package #{name} not found"
          else
            backups_file = Dotfiler::Edits::AddStep.new(backups_class_name, "yield package '#{name}'").rewrite_str backups_file
          end
        end
        @ctx.io.write backups_file_path, backups_file
      end

      desc 'remove [<name>...]', 'Removes app\'s settings from the backup.'
      def remove(*names)
        return @on_error.call 'Cannot find backup file.' unless !backups_file_path.nil? && @ctx.io.exist?(backups_file_path)

        backups_file = @ctx.io.read backups_file_path
        names.each do |name|
          if Dotfiler::SyncUtils.find_package_by_name(@backup_manager, name).nil?
            LOGGER.error "Package #{name} not found"
          else
            backups_file = Dotfiler::Edits::RemoveStep.new(backups_class_name, "yield package '#{name}'").rewrite_str backups_file
          end
        end
        @ctx.io.write backups_file_path, backups_file
      end

      desc 'list', 'Lists packages for which settings can be backed up.'
      def list
        @ctx.logger << "Packages:\n"
        @ctx.logger << Dotfiler::SyncUtils.print_nested(@backup_manager) { |item| [item.name, item.entries.select(&:children?)] }
      end

      desc 'discover', 'Discovers packages that can be added'
      def discover
        @ctx.logger << "Discovered packages:\n"
        discovered_packages = Dotfiler::SyncUtils.discover_packages(@backup_manager).to_a
        if discovered_packages.empty?
          @ctx.logger << "No new packages discovered\n"
        else
          discovered_packages.each do |package|
            @ctx.logger << package
            @ctx.logger << "\n"
          end
        end
      end

      desc 'edit NAME', 'Edit an existing package.'
      def edit(name)
        package = Dotfiler::SyncUtils.find_package_by_name @backup_manager, name
        if package.nil? || Dotfiler::SyncUtils.get_source(package).nil?
          @ctx.logger.warn 'Could not find a package to edit. It might not have been added'
        else
          Dotfiler::SyncUtils.edit_package package
        end
      end
    end

    # A CLI class that executes dotfiler.
    class Program < CommonCLI
      no_commands do
        def get_context(options)
          Dotfiler::SyncContext.new copy: options[:copy], untracked: options[:untracked], on_overwrite: method(:ask_overwrite), on_delete: method(:ask_delete), reporter: Dotfiler::LoggerReporter.new(LOGGER), logger: LOGGER, dry: options[:dry]
        end

        def ask_overwrite(backup_path, restore_path)
          # TODO(drognanar): Persist answers (ba) and (br).
          LOGGER.warn 'Needs to overwrite a file'
          LOGGER.warn "Backup: \"#{backup_path}\""
          LOGGER.warn "Restore: \"#{restore_path}\""
          @cli.choose do |menu|
            menu.prompt = 'Keep back up, restore, back up for all, restore for all?'
            menu.choice(:b) { return :backup }
            menu.choice(:r) { return :restore }
            menu.choice(:ba) { return :backup }
            menu.choice(:br) { return :restore }
          end
        end

        def ask_delete(file)
          LOGGER << "Deleting \"#{file}\"\n"
          (!options[:confirm] || @cli.agree('Do you want to remove this file? [y/n]'))
        end
      end

      desc 'init [<backups>...]', 'Initializes backups'
      option 'dir', type: :string
      option 'force', type: :boolean
      option 'dry', type: :boolean, default: false, desc: 'Print operations that would be executed by dotfiler.'
      def init(path = '')
        Dotfiler::SyncUtils.create_backup @ctx.backup_path(path), @ctx.logger, @ctx.io, force: options[:force]
      end

      desc 'sync', 'Synchronize your settings'
      option 'dry', type: :boolean, default: false, desc: 'Print operations that would be executed by dotfiler.'
      option 'copy', type: :boolean, default: false, desc: 'Copy files instead of symlinking them.'
      def sync
        @ctx.logger << "Syncing:\n"
        @backup_manager.sync!
        nothing_to_sync = @ctx.reporter.events.empty?
        @ctx.logger << "Nothing to sync\n" if nothing_to_sync
      end

      desc 'cleanup', 'Cleans up previous backups'
      option 'confirm', type: :boolean, default: true
      option 'dry', type: :boolean, default: false
      option 'untracked', type: :boolean
      def cleanup
        @backup_manager.cleanup!
        nothing_to_clean = @ctx.reporter.events(:delete).empty?
        @ctx.logger << "Nothing to clean.\n" if nothing_to_clean
      end

      desc 'status', 'Returns the sync status'
      def status
        @ctx.logger << "Current status:\n\n"
        status = @backup_manager.status
        if status.name.empty? && status.items.empty?
          @ctx.logger.warn 'No packages enabled.'
          @ctx.logger.warn 'Use ./dotfiler package add to enable packages.'
        else
          @ctx.logger << Dotfiler::SyncUtils.get_status_str(status)
        end
      end

      desc 'package <subcommand> ...ARGS', 'Add/remove packages to be backed up'
      subcommand 'package', Package
    end
  end
end
