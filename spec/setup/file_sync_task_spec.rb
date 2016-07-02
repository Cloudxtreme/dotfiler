require 'setup/file_sync_task'

module Setup

RSpec.describe FileSyncTask do
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
end

end