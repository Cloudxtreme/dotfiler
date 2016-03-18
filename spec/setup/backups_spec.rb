require 'setup/backups'

module Setup

RSpec.describe Backup do
end

RSpec.describe BackupManager do
end

RSpec.describe 'resolve_backups' do
  def assert_resolve_backups(backup_strs, *expected_backup_tuples, **options)
    expected_backups = expected_backup_tuples.map { |backup, source| [File.expand_path(backup), source] }
    expect(Setup::BackupManager.resolve_backups(backup_strs, options)).to eq(expected_backups)
  end
  
  it 'should set default values' do
    assert_resolve_backups [], [Cli::DEFAULT_BACKUP_ROOT, nil]
  end
  
  it 'should handle local file paths' do
    assert_resolve_backups ['./path'], ['./path', nil]
    assert_resolve_backups ['../path'], ['../path', nil]
    assert_resolve_backups [File.expand_path('~/username/dotfiles')], [File.expand_path('~/username/dotfiles'), nil]
    assert_resolve_backups ['~/'], ['~/', nil]
  end
  
  it 'should handle urls' do
    assert_resolve_backups ['github.com/username/path'], ['~/dotfiles/github.com/username/path', 'github.com/username/path']
  end
  
  it 'should allow to specify both local and global path' do
    assert_resolve_backups ['~/dotfiles:github.com/username/path'], ['~/dotfiles', 'github.com/username/path']
    assert_resolve_backups ['~/dotfiles:github.com:80/username/path'], ['~/dotfiles', 'github.com:80/username/path']
  end
  
  it 'should handle multiple paths' do
    assert_resolve_backups ['github.com/username/path1', 'github.com/username/path2'],
      ['~/dotfiles/github.com/username/path1', 'github.com/username/path1'],
      ['~/dotfiles/github.com/username/path2', 'github.com/username/path2']
  end
  
  it 'should allow to specify the directory' do
    assert_resolve_backups ['github.com/username/path'],
      ['~/backups/github.com/username/path', 'github.com/username/path'],
      backup_dir: File.expand_path('~/backups/')
  end
end

end # module Setup
