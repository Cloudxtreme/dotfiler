require 'setup/backups'

module Setup

RSpec.describe Backup do
end

RSpec.describe BackupManager do
end

RSpec.describe 'resolve_backups' do
  def assert_resolve_backups(backup_str, expected_backup_path, expected_source_path, **options)
    expected_backup = [File.expand_path(expected_backup_path), expected_source_path]
    expect(Setup::Backup.resolve_backup(backup_str, options)).to eq(expected_backup)
  end
  
  it 'should handle local file paths' do
    assert_resolve_backups './path', './path', nil
    assert_resolve_backups '../path', '../path', nil
    assert_resolve_backups File.expand_path('~/username/dotfiles'), File.expand_path('~/username/dotfiles'), nil
    assert_resolve_backups '~/', '~/', nil
  end
  
  it 'should handle urls' do
    assert_resolve_backups 'github.com/username/path', '~/dotfiles/github.com/username/path', 'github.com/username/path'
  end
  
  it 'should allow to specify both local and global path' do
    assert_resolve_backups '~/dotfiles:github.com/username/path', '~/dotfiles', 'github.com/username/path'
    assert_resolve_backups '~/dotfiles:github.com:80/username/path', '~/dotfiles', 'github.com:80/username/path'
  end
  
  it 'should allow to specify the directory' do
    assert_resolve_backups 'github.com/username/path',
      '~/backups/github.com/username/path', 'github.com/username/path',
      backup_dir: File.expand_path('~/backups/')
  end
end

end # module Setup
