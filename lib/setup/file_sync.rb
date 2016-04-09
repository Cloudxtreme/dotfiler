require 'setup/io'
require 'setup/logging'

module Setup

DEFAULT_FILESYNC_OPTIONS = { copy: false, backup_prefix: 'setup-backup' }

class FileMissingError < Exception
end

# Class that synchronizes files against a backup repository.
class FileSync
  def initialize(sync_time = nil, io = CONCRETE_IO)
    @sync_time = (sync_time || Time.new).strftime '%Y%m%d%H%M%S'
    @io = io
  end

  def info(options = {})
    options = DEFAULT_FILESYNC_OPTIONS.merge(options)
    FileSyncInfo.new(options, @io)
  end

  def has_data(options = {})
    info(options).errors.nil?
  end

  def sync!(options = {})
    options = DEFAULT_FILESYNC_OPTIONS.merge(options)
    sync_info = FileSyncInfo.new(options, @io)
    return if sync_info.status == :up_to_date

    case sync_info.status
    when :error then raise FileMissingError.new(sync_info.errors)
    when :backup then create_backup_file! sync_info, options
    when :overwrite_data then create_directory = save_overwrite_file! sync_info, options 
    when :resync then @io.rm_rf options[:restore_path] 
    end

    create_directory ||= sync_info.backup_directory or sync_info.restore_directory
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
  attr_reader :restore_directory, :backup_directory, :symlinked, :errors, :status, :backup_path, :has_backup, :has_restore

  def initialize(options, io = CONCRETE_IO)
    @backup_path = options[:backup_path]
    @restore_path = options[:restore_path]
    @has_restore = io.exist? @restore_path
    @has_backup = io.exist? @backup_path
    @errors = get_errors options, io
    if @errors.nil?
      @restore_directory = (@has_restore and io.directory?(@restore_path))
      @backup_directory = (@has_backup and io.directory?(@backup_path))
      @symlinked = io.identical? @backup_path, @restore_path
    end
    @status = get_status options, io
  end

  private

  def get_errors(options, io)
    if not @has_restore and not @has_backup
      "Cannot sync. Missing both backup and restore."
    end
  end

  def get_status(options, io)
    if not @errors.nil? then :error
    elsif not @has_restore then :restore
    elsif not @has_backup then :backup
    elsif files_differ? io then :overwrite_data
    elsif options[:copy] != @symlinked then :up_to_date
    else :resync
    end
  end

  # Returns true if two paths might not have the same content.
  # Returns false if the files have the same content.
  def files_differ?(io)
    not @symlinked and (@backup_directory or @restore_directory or io.read(@backup_path) != io.read(@restore_path))
  end
end

end # module Setup
