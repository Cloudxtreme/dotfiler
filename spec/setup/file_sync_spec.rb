# Tests file_sync.rb
require 'setup/file_sync'

module Setup

module MockIo
def mock_files(io, files)
  files.each_pair do |path, data|
    exists = (not data.nil?)
    allow(io).to receive(:exist?).with(path).and_return exists
    allow(io).to receive(:directory?).with(path).and_return (data == :directory) if exists
    allow(io).to receive(:read).with(path).and_return data if data.is_a? String
  end
end
end

RSpec.describe 'FileSync' do
  include MockIo
  let(:io)   { instance_double('File_IO') }
  let(:time) { instance_double('Time') }
  let(:enabled_info)       { { enabled: true, errors: nil, backup_path: 'backup/path', restore_path: 'restore/path' } }
  let(:info_disabled)      { get_sync_info enabled: false }
  let(:info_with_errors)   { get_sync_info enabled: true, errors: 'err' }
  let(:info_up_to_date)    { get_sync_info enabled: true, errors: nil, status: :up_to_date }
  let(:info_symlink_files) { get_sync_info enabled_info.merge status: :sync, copy: false, is_directory: false }
  let(:info_symlink_dirs)  { get_sync_info enabled_info.merge status: :sync, copy: false, is_directory: true }
  let(:info_copy_files)    { get_sync_info enabled_info.merge status: :sync, copy: true }
  let(:info_overwrite)     { get_sync_info enabled_info.merge status: :overwrite_data, copy: true }
  let(:info_resync)        { get_sync_info enabled_info.merge status: :resync, copy: true }


  def get_sync_task(file_sync, sync_time = nil)
    expect(time).to receive(:strftime).once.and_return '20160404111213'
    expect(FileSyncInfo).to receive(:new).and_return file_sync
    FileSync.new nil, time, io
  end

  describe 'initialize' do
    it 'should initialize default values' do
      file_sync = FileSync.new nil
      expect(file_sync.options).to eq(DEFAULT_FILESYNC_OPTIONS)
    end
  end

  describe 'cleanup' do
    it 'should remove any backup files' do
      sync_info = instance_double 'FileSync', backup_path: 'backup/path', restore_path: 'restore/path'
      sync_task = get_sync_task sync_info
      expect(io).to receive(:glob).with('backup/setup-backup-*').once.and_return ['file1', 'file2']
      expect(io).to receive(:glob).with('restore/setup-backup-*').once.and_return ['file3']
      expect(sync_task.cleanup).to eq(['file1', 'file2', 'file3'])
    end
  end

  def get_sync_info(options)
    instance_double 'FileSyncInfo', options
  end

  def get_enabled_sync_info(options)
    settings = { enabled: true, errors: nil, backup_path: 'backup/path', restore_path: 'restore/path' }
    get_sync_info settings.merge options
  end

  describe 'status' do
    it 'should return the sync info' do
      sync_info = get_sync_info({})
      expect((get_sync_task sync_info).info).to eq(sync_info)
    end
  end

  describe 'reset!' do
    it 'should not remove concrete files' do
      sync_info = get_sync_info symlinked: false
      (get_sync_task sync_info).reset!
    end

    it 'should remove restored symlinks' do
      sync_info = get_sync_info symlinked: true, restore_path: 'restore/path'
      expect(io).to receive(:rm_rf).with('restore/path').once
      (get_sync_task sync_info).reset!
    end
  end

  describe 'backup!' do
    it 'should not backup when FileSync disabled, has errors or up to date' do
      (get_sync_task info_disabled).backup!
      (get_sync_task info_with_errors).backup!
      (get_sync_task info_up_to_date).backup!
    end

    def assert_backup_steps(restore_method)
      expect(io).to receive(:mkdir_p).with('backup').once.ordered
      expect(io).to receive(:mv).with('restore/path', 'backup/path').once.ordered
      expect(io).to receive(:mkdir_p).with('restore').once.ordered
      expect(io).to receive(restore_method).with('backup/path', 'restore/path').once.ordered
    end

    it 'should create backup file and restore link' do
      assert_backup_steps :link
      (get_sync_task info_symlink_files).backup!

      assert_backup_steps :junction
      (get_sync_task info_symlink_dirs).backup!

      assert_backup_steps :cp_r
      (get_sync_task info_copy_files).backup!
    end

    it 'should rename file if overriden' do
      expect(io).to receive(:mkdir_p).with('backup').once.ordered
      expect(io).to receive(:mv).with('backup/path', 'backup/setup-backup-20160404111213-path').once.ordered
      assert_backup_steps :cp_r
      (get_sync_task info_overwrite).backup!
    end
  end

  describe 'restore!' do
    it 'should not restore when FileSync disabled, has errors or up to date' do
      (get_sync_task info_disabled).restore!
      (get_sync_task info_with_errors).restore!
      (get_sync_task info_up_to_date).restore!
    end

    it 'should create restore link' do
      expect(io).to receive(:mkdir_p).with('restore').once.ordered
      expect(io).to receive(:link).with('backup/path', 'restore/path').once.ordered
      (get_sync_task info_symlink_files).restore!

      expect(io).to receive(:mkdir_p).with('restore').once.ordered
      expect(io).to receive(:junction).with('backup/path', 'restore/path').once.ordered
      (get_sync_task info_symlink_dirs).restore!

      expect(io).to receive(:mkdir_p).with('restore').once.ordered
      expect(io).to receive(:cp_r).with('backup/path', 'restore/path').once.ordered
      (get_sync_task info_copy_files).restore!      
    end

    it 'should rename file if overriden' do
      expect(io).to receive(:mkdir_p).with('restore').once.ordered
      expect(io).to receive(:mv).with('restore/path', 'restore/setup-backup-20160404111213-path').once.ordered
      expect(io).to receive(:mkdir_p).with('restore').once.ordered
      expect(io).to receive(:cp_r).with('backup/path', 'restore/path').once.ordered
      (get_sync_task info_overwrite).restore!
    end

    it 'should delete previous restore under resync' do
      expect(io).to receive(:rm_rf).with('restore/path').once.ordered
      expect(io).to receive(:mkdir_p).with('restore').once.ordered
      expect(io).to receive(:cp_r).with('backup/path', 'restore/path').once.ordered
      (get_sync_task info_resync).restore!
    end
  end
end

RSpec.describe 'FileSyncInfo' do
  include MockIo
  let(:io)                { instance_double('File_IO') }
  let(:example_options1)  { { enabled: true, backup_path: 'backup/path', restore_path: 'restore/path', copy: false } }
  let(:example_options2)  { { enabled: false, backup_path: 'backup/path', restore_path: 'restore/path', copy: true } }
  let(:example_options3)  { { enabled: false, backup_path: 'backup/path2', restore_path: 'restore/path2', copy: true } }

  it 'should extract options' do
    expect(io).to receive(:exist?).with('backup/path').once.and_return false
    info = FileSyncInfo.new :restore, example_options1, io
    expect(info.enabled).to be true
    expect(info.backup_path).to eq('backup/path')
    expect(info.restore_path).to eq('restore/path')

    expect(io).to receive(:exist?).with('restore/path2').once.and_return false
    info = FileSyncInfo.new :backup, example_options3, io
    expect(info.enabled).to be false
    expect(info.backup_path).to eq('backup/path2')
    expect(info.restore_path).to eq('restore/path2')
  end

  it 'should return errors when files missing' do
    mock_files io, 'backup/path' => nil
    info = FileSyncInfo.new :restore, example_options1, io
    expect(info.errors).to_not be_nil
    expect(info.is_directory).to be_nil
    expect(info.symlinked).to be_nil
    expect(info.status).to be_nil

    mock_files io, 'restore/path' => nil
    info = FileSyncInfo.new :backup, example_options1, io
    expect(info.errors).to_not be_nil
    expect(info.is_directory).to be_nil
    expect(info.symlinked).to be_nil
    expect(info.status).to be_nil
  end

  def assert_backup_restore(options, symlinked, expected_status, data1, data2)
    assert_sync nil, options, symlinked, expected_status, data1, data2
  end

  def assert_sync(action_type, options, symlinked, expected_status, data1, data2)
    return [:restore, :backup].each { |type| assert_sync(type, options, symlinked, expected_status, data1, data2) } if action_type.nil?
    return [example_options1, example_options2].each { |option| assert_sync(action_type, option, symlinked, expected_status, data1, data2) } if options.nil?

    mock_files io, 'backup/path' => data1, 'restore/path' => data2
    allow(io).to receive(:identical?).and_return symlinked
    info = FileSyncInfo.new action_type, options, io
    expect(info.enabled).to eq(options[:enabled])
    expect(info.errors).to be_nil
    expect(info.symlinked).to be symlinked
    expect(info.is_directory).to eq(action_type == :restore ? data1 == :directory : data2 == :directory)
    expect(info.status).to eq(expected_status)
  end

  it 'should support sync when one file is a directory and another is a file' do
    assert_backup_restore nil, false, :overwrite_data, :directory, :file
    assert_backup_restore nil, false, :overwrite_data, :file, :directory
  end

  it 'should be up to date when files are equal' do
    assert_backup_restore example_options1, true, :up_to_date, :file, :file
    assert_backup_restore example_options1, true, :up_to_date, :directory, :directory
    assert_backup_restore example_options2, false, :up_to_date, 'same_content', 'same_content'
  end

  it 'should overwrite data when syncing directories' do
    assert_backup_restore nil, false, :overwrite_data, :directory, :directory
  end

  it 'should overwrite data when syncing different files' do
    assert_backup_restore nil, false, :overwrite_data, 'content1', 'content2'
  end

  it 'should require sync when flle is missing' do
    assert_sync :backup, nil, false, :sync, nil, :file
    assert_sync :restore, nil, false, :sync, :file, nil
  end

  it 'should require resync when restoring link to copy' do
    assert_sync :restore, example_options1, false, :resync, 'same_content', 'same_content'
    assert_sync :restore, example_options2, true, :resync, 'same_content', 'same_content'
  end
end

end # module Setup
