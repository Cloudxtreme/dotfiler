require 'setup/io'
require 'setup/logging'
require 'setup/sync_status'

module Setup
  DEFAULT_FILESYNC_OPTIONS = { copy: false, backup_prefix: 'setup-backup' }.freeze

  class FileSyncError < RuntimeError
  end

  # Class that synchronizes files against a backup repository.
  class FileSync
    def initialize(sync_time = nil, io = CONCRETE_IO)
      @sync_time = (sync_time || Time.new).strftime '%Y%m%d%H%M%S'
      @io = io
    end

    def status(options = {})
      options = DEFAULT_FILESYNC_OPTIONS.merge(options)
      FileSyncInfo.new(options, @io).status
    end

    def sync!(options = {})
      options = DEFAULT_FILESYNC_OPTIONS.merge(options)
      sync_info = FileSyncInfo.new(options, @io)
      return if sync_info.status.kind == :up_to_date

      case sync_info.status.kind
      when :error then raise FileSyncError.new(sync_info.status.status_msg)
      when :backup then create_backup_file! sync_info, options
      when :overwrite_data then create_directory = save_overwrite_file! sync_info, options
      when :resync then @io.rm_rf options[:restore_path]
      end

      create_directory ||= sync_info.backup_directory || sync_info.restore_directory
      create_restore_file! sync_info, options, create_directory
    end

    private

    def get_backup_copy_path(options)
      dir_part, file_part = File.split options[:backup_path]
      File.join dir_part, "#{options[:backup_prefix]}-#{@sync_time}-#{file_part}"
    end

    def save_overwrite_file!(sync_info, options)
      file_to_keep = options[:on_overwrite].nil? ? :backup : options[:on_overwrite].call(options[:backup_path], options[:restore_path])
      path_to_copy = file_to_keep == :backup ? options[:restore_path] : options[:backup_path]
      save_existing_file! path_to_copy, options
      create_backup_file! sync_info, options if file_to_keep == :restore

      file_to_keep == :backup ? sync_info.backup_directory : sync_info.restore_directory
    end

    def save_existing_file!(path, options)
      backup_copy_path = get_backup_copy_path(options)
      LOGGER.verbose "Saving a copy of file \"#{path}\" under \"#{File.dirname backup_copy_path}\""
      @io.mkdir_p File.dirname backup_copy_path
      @io.mv path, backup_copy_path
    end

    def create_restore_file!(sync_info, options, is_directory)
      @io.mkdir_p File.dirname options[:restore_path]

      if options[:copy]
        LOGGER.verbose "Copying \"#{options[:backup_path]}\" to \"#{options[:restore_path]}\""
        @io.cp_r options[:backup_path], options[:restore_path]
      elsif is_directory
        LOGGER.verbose "Linking \"#{options[:backup_path]}\" with \"#{options[:restore_path]}\""
        @io.junction options[:backup_path], options[:restore_path]
      else
        LOGGER.verbose "Symlinking \"#{options[:backup_path]}\" with \"#{options[:restore_path]}\""
        @io.link options[:backup_path], options[:restore_path]
      end
    end

    def create_backup_file!(sync_info, options)
      LOGGER.verbose "Moving file from \"#{options[:restore_path]}\" to \"#{options[:backup_path]}\""
      @io.mkdir_p File.dirname options[:backup_path]
      @io.mv options[:restore_path], options[:backup_path]
    end
  end

  # Returns sync information between `restore_path` and `backup_path`.
  # FileSync should not do any read IO after generating this info file.
  class FileSyncInfo
    attr_reader :restore_directory, :backup_directory, :symlinked, :status, :backup_path, :restore_path

    def initialize(options, io = CONCRETE_IO)
      name = File.basename options[:restore_path]
      @backup_path = options[:backup_path]
      @restore_path = options[:restore_path]
      @has_restore = io.exist? @restore_path
      @has_backup = io.exist? @backup_path
      if !@has_restore && !@has_backup
        @status = SyncStatus.new name, :error, 'Cannot sync. Missing both backup and restore.'.freeze
        return
      end

      @restore_directory = (@has_restore && io.directory?(@restore_path))
      @backup_directory = (@has_backup && io.directory?(@backup_path))
      @symlinked = io.identical? @backup_path, @restore_path

      @status = if !@has_restore then SyncStatus.new name, :restore
                elsif !@has_backup then SyncStatus.new name, :backup
                elsif files_differ? io then SyncStatus.new name, :overwrite_data
                elsif options[:copy] != @symlinked then SyncStatus.new name, :up_to_date
                else SyncStatus.new name, :resync
                end
    end

    private

    # Returns true if two paths might not have the same content.
    # Returns false if the files have the same content.
    def files_differ?(io)
      !@symlinked && (@backup_directory || @restore_directory || io.read(@backup_path) != io.read(@restore_path))
    end
  end
end # module Setup
