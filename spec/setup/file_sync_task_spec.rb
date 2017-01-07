require 'setup/file_sync'
require 'setup/file_sync_task'
require 'setup/io'
require 'setup/sync_context'

module Setup

RSpec.describe FileSyncTask do
  let(:io)        { instance_double(InputOutput::File_IO, dry: false) }
  let(:ctx)       { SyncContext.new io: io, sync_time: 12 }
  let(:file_sync) { instance_double(FileSync) }
  let(:options)   { { backup_path: '/backup/path', restore_to: '/restore/to' } }
  let(:task)      { FileSyncTask.new 'task', options, ctx }

  describe 'escape_dotfile_path' do
    it 'should not escape regular files' do
      expect(FileSyncTask.escape_dotfile_path 'file_path').to eq('file_path')
      expect(FileSyncTask.escape_dotfile_path '_file_path').to eq('_file_path')
      expect(FileSyncTask.escape_dotfile_path 'dir/file_path').to eq('dir/file_path')
    end

    it 'should not escape regular files with extensions' do
      expect(FileSyncTask.escape_dotfile_path 'file_path.ext').to eq('file_path.ext')
      expect(FileSyncTask.escape_dotfile_path 'file_path.ext1.ext2').to eq('file_path.ext1.ext2')
      expect(FileSyncTask.escape_dotfile_path 'dir.e/file_path.ext1.ext2').to eq('dir.e/file_path.ext1.ext2')
    end

    it 'should escape dot files' do
      expect(FileSyncTask.escape_dotfile_path '.file_path').to eq('_file_path')
      expect(FileSyncTask.escape_dotfile_path 'dir/.file_path').to eq('dir/_file_path')
      expect(FileSyncTask.escape_dotfile_path '.dir.dir/dir.dir/.file_path.ext').to eq('_dir.dir/dir.dir/_file_path.ext')
    end
  end

  describe '#info' do
    it 'should execute the info for a new FileSync' do
      expect(FileSync).to receive(:new).with(12, io).and_return file_sync
      expect(file_sync).to receive(:sync!).with(options)

      task.sync!
    end
  end

  describe '#sync!' do
    it 'should execute the sync for a new FileSync' do
      expect(FileSync).to receive(:new).with(12, io).and_return file_sync
      expect(file_sync).to receive(:info).with(options)

      task.info
    end
  end
end

end
