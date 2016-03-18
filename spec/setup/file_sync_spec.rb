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
  let(:symlink_sync_options) { { backup_path: 'backup/path', restore_path: 'restore/path', copy: false } }
  let(:copy_sync_options)    { { backup_path: 'backup/path', restore_path: 'restore/path', copy: true } }
  let(:info_with_errors)     { get_sync_info errors: 'err' }
  let(:info_up_to_date)      { get_sync_info errors: nil, status: :up_to_date }
  let(:info_sync_files)      { get_sync_info errors: nil, status: :sync, is_directory: false }
  let(:info_sync_dirs)       { get_sync_info errors: nil, status: :sync, is_directory: true }
  let(:info_overwrite)       { get_sync_info errors: nil, status: :overwrite_data }
  let(:info_resync)          { get_sync_info errors: nil, status: :resync }

  def sync_task(file_sync = nil)
    expect(time).to receive(:strftime).once.and_return '20160404111213'
    expect(FileSyncInfo).to receive(:new).once.and_return file_sync unless file_sync.nil?
    FileSync.new time, io
  end

  describe 'cleanup' do
    it 'should remove any backup files' do
      expect(io).to receive(:glob).with('backup/setup-backup-*').once.and_return ['file1', 'file2']
      expect(io).to receive(:glob).with('restore/setup-backup-*').once.and_return ['file3']
      expect(sync_task.cleanup symlink_sync_options).to eq(['file1', 'file2', 'file3'])
    end
  end

  def get_sync_info(options)
    instance_double 'FileSyncInfo', options
  end
  
  describe 'has_data' do
    it 'should have data if there are no errors' do
      expect((sync_task info_with_errors).has_data symlink_sync_options).to be false
      expect((sync_task info_up_to_date).has_data symlink_sync_options).to be true 
      expect((sync_task info_sync_files).has_data symlink_sync_options).to be true 
      expect((sync_task info_sync_dirs).has_data symlink_sync_options).to be true 
      expect((sync_task info_overwrite).has_data symlink_sync_options).to be true 
      expect((sync_task info_resync).has_data symlink_sync_options).to be true 
    end
  end

  describe 'info' do
    it 'should return the sync info' do
      sync_info = get_sync_info({})
      expect((sync_task sync_info).info).to eq(sync_info)
    end
  end

  describe 'reset!' do
    it 'should not remove concrete files' do
      sync_info = get_sync_info symlinked: false
      (sync_task sync_info).reset!
    end

    it 'should remove restored symlinks' do
      sync_info = get_sync_info symlinked: true, restore_path: 'restore/path'
      expect(io).to receive(:rm_rf).with('restore/path').once
      (sync_task sync_info).reset!
    end
  end

  describe 'backup!' do
    it 'should not backup when FileSync disabled, has errors or up to date' do
      (sync_task info_sync_files).backup! symlink_sync_options.merge(enabled: false)
      (sync_task info_with_errors).backup! symlink_sync_options
      (sync_task info_up_to_date).backup! symlink_sync_options
    end

    def assert_backup_steps(restore_method)
      expect(io).to receive(:mkdir_p).with('backup').once.ordered
      expect(io).to receive(:mv).with('restore/path', 'backup/path').once.ordered
      expect(io).to receive(:mkdir_p).with('restore').once.ordered
      expect(io).to receive(restore_method).with('backup/path', 'restore/path').once.ordered
    end

    it 'should create backup file and restore link' do
      assert_backup_steps :link
      (sync_task info_sync_files).backup! symlink_sync_options

      assert_backup_steps :junction
      (sync_task info_sync_dirs).backup! symlink_sync_options

      assert_backup_steps :cp_r
      (sync_task info_sync_files).backup! copy_sync_options
    end

    it 'should rename file if overriden' do
      expect(io).to receive(:mkdir_p).with('backup').once.ordered
      expect(io).to receive(:mv).with('backup/path', 'backup/setup-backup-20160404111213-path').once.ordered
      assert_backup_steps :cp_r
      (sync_task info_overwrite).backup! copy_sync_options
    end
  end

  describe 'restore!' do
    it 'should not restore when FileSync disabled, has errors or up to date' do
      (sync_task info_sync_files).restore! symlink_sync_options.merge(enabled: false) 
      (sync_task info_with_errors).restore! symlink_sync_options
      (sync_task info_up_to_date).restore! symlink_sync_options
    end

    it 'should create restore link' do
      expect(io).to receive(:mkdir_p).with('restore').once.ordered
      expect(io).to receive(:link).with('backup/path', 'restore/path').once.ordered
      (sync_task info_sync_files).restore! symlink_sync_options

      expect(io).to receive(:mkdir_p).with('restore').once.ordered
      expect(io).to receive(:junction).with('backup/path', 'restore/path').once.ordered
      (sync_task info_sync_dirs).restore! symlink_sync_options

      expect(io).to receive(:mkdir_p).with('restore').once.ordered
      expect(io).to receive(:cp_r).with('backup/path', 'restore/path').once.ordered
      (sync_task info_sync_files).restore! copy_sync_options      
    end

    it 'should rename file if overriden' do
      expect(io).to receive(:mkdir_p).with('restore').once.ordered
      expect(io).to receive(:mv).with('restore/path', 'restore/setup-backup-20160404111213-path').once.ordered
      expect(io).to receive(:mkdir_p).with('restore').once.ordered
      expect(io).to receive(:cp_r).with('backup/path', 'restore/path').once.ordered
      (sync_task info_overwrite).restore! copy_sync_options
    end

    it 'should delete previous restore under resync' do
      expect(io).to receive(:rm_rf).with('restore/path').once.ordered
      expect(io).to receive(:mkdir_p).with('restore').once.ordered
      expect(io).to receive(:cp_r).with('backup/path', 'restore/path').once.ordered
      (sync_task info_resync).restore! copy_sync_options
    end
  end
end

RSpec.describe 'FileSyncInfo' do
  include MockIo
  let(:io)                { instance_double('File_IO') }
  let(:example_options1)  { { enabled: true, backup_path: 'backup/path', restore_path: 'restore/path', copy: false } }
  let(:example_options2)  { { enabled: false, backup_path: 'backup/path', restore_path: 'restore/path', copy: true } }
  let(:example_options3)  { { enabled: false, backup_path: 'backup/path2', restore_path: 'restore/path2', copy: true } }

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
