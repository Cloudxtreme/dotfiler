require 'setup/io'
require 'setup/logging'
require 'setup/reporter'

module Setup
  # A context contains a set of common options passed into tasks.
  # Most importantly it provides the {#restore_path} and {#backup_path} methods
  # which allow to determine the relative location of files.
  class SyncContext
    attr_reader :options

    def initialize(options = {})
      options[:io] ||= options[:dry] ? DRY_IO : CONCRETE_IO
      options[:sync_time] ||= Time.new
      options[:backup_dir] ||= ''
      options[:restore_dir] ||= ''
      options[:reporter] ||= Reporter.new
      options[:logger] ||= Logging.logger['Setup']
      options[:packages] = SyncContext.packages_to_hash(options[:packages] || {})
      @options = options
    end

    # @return [String] full path of +relative_path+ relative to the backup directory
    # @example return backup directory
    #   SyncContext.new.backup_path
    # @example return path 'file.rb' relative to backup directory
    #   SyncContext.new.backup_path 'file.rb'
    def backup_path(relative_path = './')
      File.expand_path relative_path, @options[:backup_dir]
    end

    # @return [String] full path of +relative_path+ relative to the restore directory
    # @example return restore directory
    #   SyncContext.new.restore_path
    # @example return path 'file.rb' relative to restore directory
    #   SyncContext.new.restore_path 'file.rb'
    def restore_path(relative_path = './')
      File.expand_path relative_path, @options[:restore_dir]
    end

    # @param new_options [Hash] a mapping of option overrides
    # @return [SyncContext] a clone of self with specified option overrides
    # @example
    #   ctx1 = SyncContext.new backup_dir: '~/'
    #   ctx2 = ctx.with_options restore_dir: '~/'
    #   ctx1.backup_path == ctx2.backup_path
    def with_options(new_options)
      dup.tap { |sc| sc.options.merge!(new_options) }
    end

    # @param new_packages [Array<Class>|Hash<String, Class>] package classes to add to context.
    # @return [SyncContext] a clone of self with added packages.
    def add_packages_from_cls(new_packages)
      add_packages SyncContext.packages_to_hash(new_packages.map { |package_cls| package_cls.new self })
    end

    # @param new_packages [Array<Package>|Hash<String, Package>] packages to add to context.
    # @return [SyncContext] a clone of self with added packages.
    def add_packages(new_packages)
      with_packages packages.merge new_packages
    end

    # @param new_packages [Array<Package>|Hash<String, Package>] new packages.
    # @return [SyncContext] a clone of self with specified packages.
    def with_packages(new_packages)
      with_options packages: SyncContext.packages_to_hash(new_packages)
    end

    # @param new_backup_dir [String] a path for new backup dir
    # @return [SyncContext] a clone of self with a specified backup dir
    def with_backup_dir(new_backup_dir)
      with_options backup_dir: backup_path(new_backup_dir)
    end

    # @param new_restore_dir [String] a path for new restore dir
    # @return [SyncContext] a clone of self with a specified restore dir
    def with_restore_dir(new_restore_dir)
      with_options restore_dir: restore_path(new_restore_dir)
    end

    # @return [SyncContext] a clone of self.
    def dup
      SyncContext.new @options.dup
    end

    # @return [InputOutput::FileIO] IO to be used by tasks.
    def io
      @options[:io]
    end

    # @return [HashSet<String, Package>] Mapping from package name to a package.
    def packages
      @options[:packages]
    end

    # @return [Reporter] reporter to be used by tasks.
    def reporter
      @options[:reporter]
    end

    # @return [Logger] logger to be used by tasks.
    def logger
      @options[:logger]
    end

    private

    def self.packages_to_hash(packages)
      return packages if packages.is_a? Hash
      packages.map { |package| [package.name, package] }.to_h
    end
  end
end # module Setup
