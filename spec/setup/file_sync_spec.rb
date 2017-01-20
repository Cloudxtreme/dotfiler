# Tests file_sync.rb
require 'setup/file_sync'
require 'setup/sync_status'

module Setup
  module MockIo
    def mock_files(io, files)
      files.each_pair do |path, data|
        exists = !data.nil?
        allow(io).to receive(:exist?).with(path).and_return exists
        allow(io).to receive(:directory?).with(path).and_return(data == :directory) if exists
        allow(io).to receive(:read).with(path).and_return data if data.is_a? String
      end
    end
  end

  RSpec.describe FileSync do
    include MockIo
    let(:io)                   { instance_double(InputOutput::FileIO) }
    let(:time)                 { instance_double(Time, strftime: '20160404111213') }
    let(:symlink_sync_options) { { backup_path: 'backup/path', restore_path: 'restore/path', copy: false } }
    let(:copy_sync_options)    { { backup_path: 'backup/path', restore_path: 'restore/path', copy: true } }
    let(:info_with_errors)     { get_sync_info status: SyncStatus.new('name', :error, 'err') }
    let(:info_up_to_date)      { get_sync_info status: SyncStatus.new('name', :up_to_date) }
    let(:info_restore_files)   { get_sync_info status: SyncStatus.new('name', :restore), backup_directory: false, restore_directory: false }
    let(:info_backup_files)    { get_sync_info status: SyncStatus.new('name', :backup), backup_directory: false, restore_directory: false }
    let(:info_restore_dirs)    { get_sync_info status: SyncStatus.new('name', :restore), backup_directory: true, restore_directory: true }
    let(:info_backup_dirs)     { get_sync_info status: SyncStatus.new('name', :backup), backup_directory: true, restore_directory: true }
    let(:info_overwrite)       { get_sync_info status: SyncStatus.new('name', :overwrite_data), backup_directory: false, restore_directory: false }
    let(:info_resync)          { get_sync_info status: SyncStatus.new('name', :resync), backup_directory: false, restore_directory: false }

    def file_sync(file_sync_info = nil)
      expect(FileSyncInfo).to receive(:new).once.and_return file_sync_info unless file_sync_info.nil?
      FileSync.new time, io
    end

    def get_sync_info(options)
      instance_double FileSyncInfo, options
    end

    describe '#info' do
      it 'should return the sync info' do
        expect((file_sync info_up_to_date).status).to eq(info_up_to_date.status)
      end
    end

    describe '#sync!' do
      context 'when everything is up-to-date' do
        it 'should not touch any files' do
          (file_sync info_up_to_date).sync! symlink_sync_options
        end
      end

      context 'when files are missing' do
        it 'should throw exception' do
          expect { (file_sync info_with_errors).sync! symlink_sync_options }.to raise_error(FileSyncError)
        end
      end

      context 'when only backup file is present' do
        it 'should create restore link' do
          expect(io).to receive(:mkdir_p).with('restore').once.ordered
          expect(io).to receive(:link).with('backup/path', 'restore/path').once.ordered
          (file_sync info_restore_files).sync! symlink_sync_options

          expect(io).to receive(:mkdir_p).with('restore').once.ordered
          expect(io).to receive(:junction).with('backup/path', 'restore/path').once.ordered
          (file_sync info_restore_dirs).sync! symlink_sync_options

          expect(io).to receive(:mkdir_p).with('restore').once.ordered
          expect(io).to receive(:cp_r).with('backup/path', 'restore/path').once.ordered
          (file_sync info_restore_files).sync! copy_sync_options
        end
      end

      def assert_backup_steps(restore_method)
        expect(io).to receive(:mkdir_p).with('backup').once.ordered
        expect(io).to receive(:mv).with('restore/path', 'backup/path').once.ordered
        expect(io).to receive(:mkdir_p).with('restore').once.ordered
        expect(io).to receive(restore_method).with('backup/path', 'restore/path').once.ordered
      end

      context 'when only restore file is present' do
        it 'should create backup file and restore link' do
          assert_backup_steps :link
          (file_sync info_backup_files).sync! symlink_sync_options

          assert_backup_steps :junction
          (file_sync info_backup_dirs).sync! symlink_sync_options

          assert_backup_steps :cp_r
          (file_sync info_backup_files).sync! copy_sync_options
        end
      end

      context 'when overriden' do
        it 'should restore up when (b)' do
          expect(io).to receive(:mkdir_p).with('backup').once.ordered
          expect(io).to receive(:mv).with('restore/path', 'backup/setup-backup-20160404111213-path').once.ordered
          expect(io).to receive(:mkdir_p).with('restore').once.ordered
          expect(io).to receive(:cp_r).with('backup/path', 'restore/path').once.ordered

          options = copy_sync_options.merge on_overwrite: proc { :backup }
          (file_sync info_overwrite).sync! options
        end

        it 'should backup when (r)' do
          expect(io).to receive(:mkdir_p).with('backup').once.ordered
          expect(io).to receive(:mv).with('backup/path', 'backup/setup-backup-20160404111213-path').once.ordered
          expect(io).to receive(:mkdir_p).with('backup').once.ordered
          expect(io).to receive(:mv).with('restore/path', 'backup/path')
          expect(io).to receive(:mkdir_p).with('restore').once.ordered
          expect(io).to receive(:cp_r).with('backup/path', 'restore/path')

          options = copy_sync_options.merge on_overwrite: proc { :restore }
          (file_sync info_overwrite).sync! options
        end
      end

      context 'when resyncing' do
        it 'should should delete previous restore' do
          expect(io).to receive(:rm_rf).with('restore/path').once.ordered
          expect(io).to receive(:mkdir_p).with('restore').once.ordered
          expect(io).to receive(:cp_r).with('backup/path', 'restore/path').once.ordered
          (file_sync info_resync).sync! copy_sync_options
        end
      end
    end
  end

  RSpec.describe FileSyncInfo do
    include MockIo
    let(:io)                { instance_double(InputOutput::FileIO) }
    let(:example_options1)  { { enabled: true, backup_path: 'backup/path', restore_path: 'restore/path', copy: false } }
    let(:example_options2)  { { enabled: false, backup_path: 'backup/path', restore_path: 'restore/path', copy: true } }
    let(:example_options3)  { { enabled: false, backup_path: 'backup/path2', restore_path: 'restore/path2', copy: true } }

    it 'should return errors when files missing' do
      mock_files io, 'backup/path' => nil, 'restore/path' => nil
      info = FileSyncInfo.new example_options1, io
      expect(info.status.status_msg).to_not be_nil
      expect(info.backup_directory).to be_nil
      expect(info.restore_directory).to be_nil
      expect(info.symlinked).to be_nil
      expect(info.status.kind).to eq(:error)
    end

    def assert_sync(options, symlinked, expected_status, data1, data2)
      return [example_options1, example_options2].each { |option| assert_sync(option, symlinked, expected_status, data1, data2) } if options.nil?

      mock_files io, 'backup/path' => data1, 'restore/path' => data2
      allow(io).to receive(:identical?).and_return symlinked
      info = FileSyncInfo.new options, io
      expect(info.status.status_msg).to be_nil
      expect(info.symlinked).to be symlinked
      expect(info.backup_directory).to eq(data1 == :directory)
      expect(info.restore_directory).to eq(data2 == :directory)
      expect(info.status.kind).to eq(expected_status)
    end

    it 'should support sync when one file is a directory and another is a file' do
      assert_sync nil, false, :overwrite_data, :directory, :file
      assert_sync nil, false, :overwrite_data, :file, :directory
    end

    it 'should be up to date when files are equal' do
      assert_sync example_options1, true, :up_to_date, :file, :file
      assert_sync example_options1, true, :up_to_date, :directory, :directory
      assert_sync example_options2, false, :up_to_date, 'same_content', 'same_content'
    end

    it 'should overwrite data when syncing directories' do
      assert_sync nil, false, :overwrite_data, :directory, :directory
    end

    it 'should overwrite data when syncing different files' do
      assert_sync nil, false, :overwrite_data, 'content1', 'content2'
    end

    it 'should require sync when flle is missing' do
      assert_sync nil, false, :backup, nil, :file
      assert_sync nil, false, :restore, :file, nil
    end

    it 'should require resync when restoring link to copy' do
      assert_sync example_options1, false, :resync, 'same_content', 'same_content'
      assert_sync example_options2, true, :resync, 'same_content', 'same_content'
    end
  end
end # module Setup
