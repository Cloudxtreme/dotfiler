require 'setup/backups'
require 'setup/sync_context'

require 'pathname'
require 'yaml/store'

module Setup

RSpec.describe Backup do
  let(:io)             { instance_double(InputOutput::File_IO, dry: false) }
  let(:store_factory)  { class_double(YAML::Store) }
  let(:ctx)            { SyncContext.create(io).with_backup_root('/backup/dir')  }
  let(:package_a)      { instance_double(Package, name: 'a') }
  let(:package_c)      { instance_double(Package, name: 'c') }
  let(:package_d)      { instance_double(Package, name: 'd') }
  let(:package_b2)     { instance_double(Package, name: 'b2') }
  let(:package_c_cls)  { class_double(Package) }
  let(:package_b2_cls) { class_double(Package) }
  let(:packages)       { [package_a, package_b2, package_c, package_d] }

  def get_backup(packages)
    backup = Backup.new(ctx)
    backup.packages = packages
    backup
  end

  describe '#initialize' do
    it 'should initialize from config files' do
      backup = get_backup([package_a])
      expect(backup.packages).to eq([package_a])
    end
  end

  # TODO(drognanar): Test new discovery/update mechanism
  def verify_backup_save(backup, update_names, expected_package_names)
    if not Set.new(update_names).intersection(Set.new(backup.packages.keys)).empty?
      expect(backup_store).to receive(:transaction).with(false).and_yield backup_store
      expect(backup_store).to receive(:[]=).with('enabled_package_names', expected_package_names[:enabled])
      expect(backup_store).to receive(:[]=).with('disabled_package_names', expected_package_names[:disabled])
    end
  end

  def assert_enable_packages(initial_package_names)
    backup = get_backup packages
    verify_backup_save(backup, enabled_package_names, expected_package_names)

    backup.enable_packages! enabled_package_names
    expect(backup.enabled_package_names).to eq(Set.new expected_package_names[:enabled])
    expect(backup.disabled_package_names).to eq(Set.new expected_package_names[:disabled])
  end

  def assert_disable_packages(initial_package_names)
    backup = get_backup packages
    verify_backup_save(backup, disabled_package_names, expected_package_names)

    backup.disable_packages! disabled_package_names
    expect(backup.enabled_package_names).to eq(Set.new expected_package_names[:enabled])
    expect(backup.disabled_package_names).to eq(Set.new expected_package_names[:disabled])
  end

  describe '#discover_packages' do
    it 'should include packages not added to the enabled and disabled packages that have data' do
      stub_const 'Setup::APPLICATIONS', [package_c_cls, package_b2_cls]

      backup = get_backup [package_a, package_d]
      expect(package_c_cls).to receive(:new).and_return package_c
      expect(package_c).to receive(:should_execute).and_return true
      expect(package_c).to receive(:has_data).and_return true
      expect(package_b2_cls).to receive(:new).and_return package_b2
      expect(package_b2).to receive(:should_execute).and_return true
      expect(package_b2).to receive(:has_data).and_return true
      expect(backup.discover_packages).to eq([package_c, package_b2])
    end

    it 'should not include packages with no data' do
      stub_const 'Setup::APPLICATIONS', [package_c_cls]

      backup = get_backup packages
      expect(package_c_cls).to receive(:new).and_return package_c
      expect(package_c).to receive(:should_execute).and_return true
      expect(package_c).to receive(:has_data).and_return false
      expect(backup.discover_packages).to eq([])
    end

    it 'should not include packages with not matching platform' do
      stub_const 'Setup::APPLICATIONS', [package_c_cls]

      backup = get_backup packages
      expect(package_c_cls).to receive(:new).and_return package_c
      expect(package_c).to receive(:should_execute).and_return false
      expect(backup.discover_packages).to eq([])
    end
  end

  describe '#packages_to_run' do
    it 'should include an enabled package with matching platform' do
      backup = get_backup [package_a]
      expect(package_a).to receive(:should_execute).and_return true
      expect(backup.packages_to_run).to eq([package_a])

      backup = get_backup [package_a]
      expect(package_a).to receive(:should_execute).and_return false
      expect(backup.packages_to_run).to eq([])
    end
  end

  def assert_resolve_backup(backup_str, expected_backup_path, expected_source_path, **options)
    expected_backup = [File.expand_path(expected_backup_path), expected_source_path]
    expect(Setup::Backup.resolve_backup(backup_str, options)).to eq(expected_backup)
  end

  describe '#resolve_backup' do
    it 'should handle local file paths' do
      assert_resolve_backup './path', './path', nil
      assert_resolve_backup '../path', '../path', nil
      assert_resolve_backup File.expand_path('~/username/dotfiles'), File.expand_path('~/username/dotfiles'), nil
      assert_resolve_backup '~/', '~/', nil
    end

    it 'should handle urls' do
      assert_resolve_backup 'github.com/username/path', '~/dotfiles/github.com/username/path', 'https://github.com/username/path'
    end

    it 'should allow to specify both local and global path' do
      assert_resolve_backup '~/dotfiles;github.com/username/path', '~/dotfiles', 'https://github.com/username/path'
      assert_resolve_backup '~/dotfiles;github.com:80/username/path', '~/dotfiles', 'https://github.com:80/username/path'
      assert_resolve_backup '~/dotfiles;~/otherfiles', '~/dotfiles', '~/otherfiles'
    end

    it 'should allow to specify the directory' do
      assert_resolve_backup 'github.com/username/path',
        '~/backups/github.com/username/path', 'https://github.com/username/path',
        backup_dir: File.expand_path('~/backups/')
    end
  end
end

RSpec.describe BackupManager do
  let(:io)             { instance_double(InputOutput::File_IO, dry: false) }
  let(:ctx)            { SyncContext.create(io) }
  let(:manager_store)  { instance_double(YAML::Store, path: '') }
  let(:backup1)        { instance_double(Backup) }
  let(:backup2)        { instance_double(Backup) }

  let(:backup_manager) do
    allow(manager_store).to receive(:transaction).and_yield(manager_store)
    BackupManager.new(ctx, manager_store)
  end

  describe '#create_backup!' do
    it 'should not create backup if already added to the manager' do
      backup_manager.backup_paths = ['/existing/backup/']

      expected_output = 'W: Backup "/existing/backup/" already exists' + "\n"
      backup_manager.create_backup! ['/existing/backup/', nil]
      expect(@log_output.readline).to eq(expected_output)
    end

    it 'should not create backup if backup directory is not empty' do
      backup_manager.backup_paths = ['/existing/backup/']
      expect(io).to receive(:exist?).with('/backup/dir').ordered.and_return true
      expect(io).to receive(:entries).with('/backup/dir').ordered.and_return ['a']

      backup_manager.create_backup! ['/backup/dir', nil]
      expect(@log_output.readlines.join).to eq(
"Creating a backup at \"/backup/dir\"
W: Cannot create backup. The folder /backup/dir already exists and is not empty.
")
    end

    it 'should update configuration file if directory already present' do
      backup_manager.backup_paths = ['/existing/backup/']
      expect(io).to receive(:exist?).with('/backup/dir').ordered.and_return true
      expect(io).to receive(:entries).with('/backup/dir').ordered.and_return []
      expect(manager_store).to receive(:[]=).with('backups', ['/existing/backup/', '/backup/dir']).ordered.and_return ['/backup/dir']

      backup_manager.create_backup! ['/backup/dir', nil]
    end

    it 'should clone the repository if source present' do
      backup_manager.backup_paths = ['/existing/backup/']
      expect(io).to receive(:exist?).with('/backup/dir').ordered.and_return true
      expect(io).to receive(:entries).with('/backup/dir').ordered.and_return []
      expect(io).to receive(:shell).with('git clone "example.com/username/dotfiles" -o "/backup/dir"').ordered
      expect(manager_store).to receive(:[]=).with('backups', ['/existing/backup/', '/backup/dir']).ordered.and_return ['/backup/dir']

      backup_manager.create_backup! ['/backup/dir', 'example.com/username/dotfiles']
    end

    it 'should create the folder if missing' do
      backup_manager.backup_paths = ['/existing/backup/']
      expect(io).to receive(:exist?).with('/backup/dir').ordered.and_return false
      expect(io).to receive(:mkdir_p).with('/backup/dir').ordered
      expect(manager_store).to receive(:[]=).with('backups', ['/existing/backup/', '/backup/dir']).ordered.and_return ['/backup/dir']

      backup_manager.create_backup! ['/backup/dir', nil]
    end
  end
end

end # module Setup
