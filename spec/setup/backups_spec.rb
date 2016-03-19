require 'setup/backups'

require 'pathname'
require 'yaml/store'

module Setup

RSpec.describe Backup do
  it '' do
    # expect(io).to receive(:read).with(Pathname('/backup/dir/config.yml')).and_return '{}'
    # expect(io).to receive(:exist?).with(Pathname('/backup/dir/_tasks')).and_return false
    # expect(io).to receive(:exist?).with(Backup::APPLICATIONS_DIR).and_return false
  end
  
  describe 'enable_tasks' do
  end
  
  describe 'disable_tasks' do
  end
  
  describe 'new_tasks' do
  end
  
  describe 'tasks_to_run' do
  end
end

RSpec.describe BackupManager do
  let(:io)             { instance_double(InputOutput::File_IO) }
  let(:host_info)      { { test_info: true } }
  let(:store_factory)  { class_double(YAML::Store) }
  let(:manager_store)  { instance_double(YAML::Store) }
  let(:backup_store1)  { instance_double(YAML::Store) }
  
  let(:backup_manager) do
    allow(manager_store).to receive(:transaction).and_yield(manager_store)
    allow(backup_store1).to receive(:transaction).and_yield(backup_store1)
    expect(store_factory).to receive(:new).with('/config/').and_return manager_store
    BackupManager.new io: io, host_info: host_info, store_factory: store_factory, config_path: '/config/'
  end
  
  it 'should get host info by default' do
    # backup_manager = BackupManager.new io: io, store_factory: store_factory, config_path: '/config/'
    # backup_manager.get_backups
  end
  
  describe 'get_backups' do
    it 'should get no backups if the file is missing' do
      expect(manager_store).to receive(:transaction).with(true).and_return []
      
      expect(backup_manager.get_backups).to eq([])
    end
    
    it 'should create backups from their dirs' do
      expect(manager_store).to receive(:transaction).with(true).and_yield(manager_store)
      expect(manager_store).to receive(:fetch).with('backups', []).and_return ['/backup/dir'] 
      expect(Backup).to receive(:new).with('/backup/dir', host_info, io, store_factory).and_return 'backup'
      
      expect(backup_manager.get_backups).to eq(['backup'])
    end
  end
  
  describe 'new_backup_tasks' do
  end
  
  describe 'create_backup' do
    it 'should not create backup if backup directory is not empty' do
      expect(io).to receive(:exist?).with('/backup/dir').and_return true
      expect(io).to receive(:entries).with('/backup/dir').and_return ['a'] 
      backup_manager.create_backup ['/backup/dir', nil]
    end
    
    it 'should update configuration file if directory already present' do
      expect(io).to receive(:exist?).with('/backup/dir').and_return true
      expect(io).to receive(:entries).with('/backup/dir').and_return []
      expect(manager_store).to receive(:[]).with('backups').and_return ['/existing/backup/']
      expect(manager_store).to receive(:[]=).with('backups', ['/existing/backup/', '/backup/dir']).and_return ['/backup/dir']
      
      backup_manager.create_backup ['/backup/dir', nil]
    end
    
    it 'should clone the repository if source present' do
      expect(io).to receive(:exist?).with('/backup/dir').and_return true
      expect(io).to receive(:entries).with('/backup/dir').and_return []
      expect(io).to receive(:shell).with('git clone "example.com/username/dotfiles" -o "/backup/dir"')
      expect(manager_store).to receive(:[]).with('backups').and_return ['/existing/backup/']
      expect(manager_store).to receive(:[]=).with('backups', ['/existing/backup/', '/backup/dir']).and_return ['/backup/dir']
      
      backup_manager.create_backup ['/backup/dir', 'example.com/username/dotfiles']
    end
    
    it 'should create the folder if missing' do
      expect(io).to receive(:exist?).with('/backup/dir').and_return false
      expect(io).to receive(:mkdir_p).with('/backup/dir')
      expect(manager_store).to receive(:[]).with('backups').and_return ['/existing/backup/']
      expect(manager_store).to receive(:[]=).with('backups', ['/existing/backup/', '/backup/dir']).and_return ['/backup/dir']
      
      backup_manager.create_backup ['/backup/dir', nil]
    end
  end
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

RSpec.describe 'print_new_tasks' do
end

RSpec.describe 'classify_new_tasks' do
end

end # module Setup
