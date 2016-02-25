require 'fileutils'
require_relative './labels'

module Setup

# Represents a single task that copies multiple files.
class CopyTask
  attr_accessor :files, :name, :labels

  def initialize(config, label, path_root, backup_root)
    @path_root = path_root
    @backup_root = backup_root
    @label = label

    @config = config
    @root = Setup::get_config_value(config['root'], label) || ''
    @name = config['name']
    @labels = config['labels']
    @files = config['files'].map(&method(:resolve_file))
  end

  # Returns whether a task should be executed given the set of labels.
  def should_execute
    @labels.nil? or @labels.include? @label
  end

  def get_backup_path(restore_path)
    restore_path
      .split(File::Separator)
      .map {|part| part.sub(/^\./, '_')}
      .join File::Separator
  end

  # Resolve a single file entry into a backup_path and restore_path.
  def resolve_file(path)
    if path.is_a? String
      restore_path = File.expand_path(Pathname(@root).join(path), @path_root)
      backup_path = File.expand_path(Pathname(@backup_root).join(@name, get_backup_path(path)))
      {restore_path: restore_path, backup_path: backup_path}
    elsif path.is_a? Hash
      path
    end
  end

  # Backs up the files.
  # NOTE: Not necessary when performing symlinks.
  def backup(copy=false)
    @files.each { |file| CopyTask.backup_file(file, copy) }
  end

  # Restores all files.
  def restore(copy=false)
    @files.each { |file| CopyTask.restore_file(file, copy) }
  end

  def cleanup
    backup_files_glob = Pathname(@backup_root).join('**/setup-backup-*')
    Dir.glob(backup_files_glob).each { |file| FileUtils.rm_rf file }
  end

  # Deletes restored config files.
  def reset
    @files.each &CopyTask.method(:reset_file)
  end

  def status
    @files.map { |file| file } 
  end

  def CopyTask.rename_file(path)
    return unless File.exists? path

    # Get the new name.
    dir_part, file_part = File.split path
    timestamp = Time.new.strftime '%Y%m%d%H%M%S'
    new_path = File.join dir_part, "setup-backup-#{timestamp}-#{file_part}"

    # Rename the file.
    FileUtils.mv path, new_path
  end

  # Undoes a restore command.
  # NOTE: Does not necessarily completely undo a command.
  # Just removes symlinks.
  def CopyTask.reset_file(file)
    restore_path = file[:restore_path]
    backup_path = file[:backup_path]

    if File.identical?(restore_path, backup_path)
      FileUtils.rm_rf restore_path
    end
  end

  def CopyTask.file_contents_equal?(path1, path2)
    not File.directory?(path1) and
      not File.directory?(path2) and
      IO.read(path1) == IO.read(path2)
  end

  # Returns if two paths have the same content.
  # Returns false for non-symlinked directories.
  def CopyTask.files_equal?(path1, path2)
    File.exists?(path1) and
      File.exists?(path2) and
      (File.identical?(path1, path2) or file_contents_equal?(path1, path2))
  end

  def CopyTask.link_files(old_path, link_path, copy=false)
    if File.exists? link_path
      FileUtils.rm_rf link_path
    end

    if copy
      File.cp_r old_path, link_path
    elsif File.directory? old_path
      puts `cmd /c \"mklink /J \"#{link_path}\" \"#{old_path}\"\"`
    else
      File.link(old_path, link_path)
    end
  end

  # Synchronises restore_path with backup_path.
  # Assumes that if both files exist they are equal.
  def CopyTask.sync(restore_path, backup_path, copy)
    # Ensure backup directory exists.
    backup_dir = File.dirname backup_path
    FileUtils.mkdir_p backup_dir

    if not File.exists? backup_path
      FileUtils.cp_r restore_path, backup_path
    end

    if not File.exists? restore_path or
      (copy and File.identical?(restore_path, backup_path)) or
      (not copy and not File.identical?(restore_path, backup_path))
        link_files(backup_path, restore_path, copy)
    end
  end

  def CopyTask.backup_file(file, copy)
    restore_path = file[:restore_path]
    backup_path = file[:backup_path]
    return unless File.exists? restore_path or File.exists? backup_path
    
    if File.exists?(backup_path) and File.exists?(restore_path) and not files_equal?(restore_path, backup_path)
      CopyTask.rename_file(backup_path)
    end

    sync(restore_path, backup_path, copy)
  end

  def CopyTask.restore_file(file, copy)
    restore_path = file[:restore_path]
    backup_path = file[:backup_path]
    return unless File.exists? backup_path

    if File.exists?(restore_path) and not files_equal?(restore_path, backup_path)
      rename_file(restore_path)
    end

    sync(restore_path, backup_path, copy)
  end
end

end
