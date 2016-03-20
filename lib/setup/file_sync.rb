require 'setup/io'

module Setup

DEFAULT_FILESYNC_OPTIONS = { enabled: true, copy: false, backup_prefix: 'setup-backup' }

# Class that synchronizes files.
class FileSync
  def initialize(sync_time = nil, io = IO)
    @sync_time = (sync_time || Time.new).strftime '%Y%m%d%H%M%S'
    @io = io
  end

  def cleanup(options = {})
    options = DEFAULT_FILESYNC_OPTIONS.merge(options)
    cleanup_globs(options).map { |glob| @io.glob glob }.flatten
  end

  def info(options = {})
    options = DEFAULT_FILESYNC_OPTIONS.merge(options)
    get_sync_info(:backup, options)
  end

  def has_data(options = {})
    options = DEFAULT_FILESYNC_OPTIONS.merge(options)
    get_sync_info(:backup, options).errors.nil?
  end

  # Removes symlinks.
  def reset!(options = {})
    options = DEFAULT_FILESYNC_OPTIONS.merge(options)
    sync_info = get_sync_info :backup, options
    @io.rm_rf options[:restore_path] if sync_info.symlinked
  end

  def backup!(options = {})
    options = DEFAULT_FILESYNC_OPTIONS.merge(options)
    sync_info = get_sync_info :backup, options
    return if not options[:enabled] or not sync_info.errors.nil? or sync_info.status == :up_to_date
    save_existing_file!(options[:backup_path], options) if sync_info.status == :overwrite_data
    create_backup_file! sync_info, options
    create_restore_file! sync_info, options
  end

  def restore!(options = {})
    options = DEFAULT_FILESYNC_OPTIONS.merge(options)
    sync_info = get_sync_info :restore, options
    return if not options[:enabled] or not sync_info.errors.nil? or sync_info.status == :up_to_date
    save_existing_file!(options[:restore_path], options) if sync_info.status == :overwrite_data
    @io.rm_rf(options[:restore_path]) if sync_info.status == :resync
    create_restore_file! sync_info, options
  end

  private

  def get_backup_path(options)
    dir_part, file_part = File.split options[:backup_path]
    File.join dir_part, "#{options[:backup_prefix]}-#{@sync_time}-#{file_part}"
  end

  def get_sync_info(action, options)
    FileSyncInfo.new(action, options, @io)
  end

  def cleanup_globs(options)
    backup_dir, _ = File.split options[:backup_path]
    backup_files_glob = File.join backup_dir, 'setup-backup-*'
    [backup_files_glob]
  end

  def save_existing_file!(path, options)
    backup_path = get_backup_path(options)
    @io.mkdir_p File.dirname backup_path
    @io.mv path, backup_path
  end

  def create_restore_file!(sync_info, options)
    @io.mkdir_p File.dirname options[:restore_path]
    if options[:copy]
      @io.cp_r options[:backup_path], options[:restore_path]
    elsif sync_info.is_directory
      @io.junction options[:backup_path], options[:restore_path]
    else
      @io.link options[:backup_path], options[:restore_path]
    end
  end

  def create_backup_file!(sync_info, options)
    @io.mkdir_p File.dirname options[:backup_path]
    @io.mv options[:restore_path], options[:backup_path]
  end
end

# Returns sync information between `restore_path` and `backup_path`.
# FileSync should not do any read IO after generating this info file.
class FileSyncInfo
  attr_reader :is_directory, :symlinked, :errors, :status

  def initialize(sync_action, options, io = IO)
    @backup_path = options[:backup_path]
    @restore_path = options[:restore_path]
    @errors = get_errors sync_action, options, io
    if @errors.nil?
      @is_directory = sync_action == :backup ? io.directory?(@restore_path) : io.directory?(@backup_path)
      @symlinked = io.identical? @backup_path, @restore_path
      @status = get_status options, io
    end
  end

  private

  def get_errors(sync_action, options, io)
    if sync_action == :backup and not io.exist? @restore_path
      "Cannot backup: missing #{@restore_path}"
    elsif sync_action == :restore and not io.exist? @backup_path
      "Cannot restore: missing #{@backup_path}"
    end
  end

  def get_status(options, io)
    if not io.exist?(@restore_path) or not io.exist?(@backup_path)
      :sync
    elsif files_differ? @backup_path, @restore_path, io
      :overwrite_data
    elsif options[:copy] != @symlinked
      :up_to_date
    else
      :resync
    end
  end

  # Returns true if two paths might not have the same content.
  # Returns false if the files have the same content.
  def files_differ?(path1, path2, io)
    not @symlinked and (io.directory?(path1) or io.directory?(path2) or io.read(path1) != io.read(path2))
  end
end

end # module Setup
