require 'setup/backups'
require 'setup/sync_context'

require 'pathname'
require 'yaml/store'

module Setup

RSpec.describe Backup do
  let(:io)             { instance_double(InputOutput::File_IO, dry: false) }
  let(:store_factory)  { class_double(YAML::Store) }
  let(:ctx)            { SyncContext.new backup_dir: '/backup_dir', io: io }
  let(:package_a)      { instance_double(Package, name: 'a') }
  let(:package_c)      { instance_double(Package, name: 'c') }
  let(:package_d)      { instance_double(Package, name: 'd') }
  let(:package_b2)     { instance_double(Package, name: 'b2') }
  let(:package_c_cls)  { class_double(Package) }
  let(:package_b2_cls) { class_double(Package) }
  let(:packages)       { [package_a, package_b2, package_c, package_d] }

  def get_backup(packages, ctx)
    Backup.new(ctx).tap { |backup| backup.items = packages }
  end

  describe '#initialize' do
    it 'should initialize from config files' do
      backup = get_backup([package_a], ctx)
      expect(backup.to_a).to eq([package_a])
    end
  end

  # TODO(drognanar): Test new discovery/update mechanism
  def verify_backup_save(backup, update_names, expected_package_names)
    if not Set.new(update_names).intersection(Set.new(backup.to_a.keys)).empty?
      expect(backup_store).to receive(:transaction).with(false).and_yield backup_store
      expect(backup_store).to receive(:[]=).with('enabled_package_names', expected_package_names[:enabled])
      expect(backup_store).to receive(:[]=).with('disabled_package_names', expected_package_names[:disabled])
    end
  end

  def assert_enable_packages(initial_package_names)
    backup = get_backup packages, ctx
    verify_backup_save(backup, enabled_package_names, expected_package_names)

    backup.enable_packages! enabled_package_names
    expect(backup.enabled_package_names).to eq(Set.new expected_package_names[:enabled])
    expect(backup.disabled_package_names).to eq(Set.new expected_package_names[:disabled])
  end

  def assert_disable_packages(initial_package_names)
    backup = get_backup packages, ctx
    verify_backup_save(backup, disabled_package_names, expected_package_names)

    backup.disable_packages! disabled_package_names
    expect(backup.enabled_package_names).to eq(Set.new expected_package_names[:enabled])
    expect(backup.disabled_package_names).to eq(Set.new expected_package_names[:disabled])
  end

  def assert_resolve_backup(backup_str, expected_backup_path, expected_source_path, **options)
    expected_backup = [File.expand_path(expected_backup_path), expected_source_path]
    expect(Setup::Backup.resolve_backup(backup_str, options)).to eq(expected_backup)
  end
end

RSpec.describe Backups do
  let(:io)             { instance_double(InputOutput::File_IO, dry: false) }
  let(:ctx)            { SyncContext.new io: io }

  describe '#create_backup!' do
    it 'should create backup if directory does not exist' do
      expect(io).to receive(:exist?).with('/backup/dir').ordered.and_return false
      expect(io).to receive(:mkdir_p).with('/backup/dir')
      expect(io).to receive(:write).with('/backup/dir/backups.rb', Templates::backups)
      expect(io).to receive(:write).with('/backup/dir/sync.rb', Templates::sync)

      Backups::create_backup '/backup/dir', ctx.logger, io
    end

    it 'should create backup if force passed' do
      expect(io).to receive(:exist?).with('/backup/dir').ordered.and_return true
      expect(io).to receive(:entries).with('/backup/dir').ordered.and_return []
      expect(io).to receive(:mkdir_p).with('/backup/dir')
      expect(io).to receive(:write).with('/backup/dir/backups.rb', Templates::backups)
      expect(io).to receive(:write).with('/backup/dir/sync.rb', Templates::sync)

      Backups::create_backup '/backup/dir', ctx.logger, io
    end

    it 'should not create backup if backup directory is not empty' do
      expect(io).to receive(:exist?).with('/backup/dir').ordered.and_return true
      expect(io).to receive(:entries).with('/backup/dir').ordered.and_return ['a']

      Backups::create_backup '/backup/dir', ctx.logger, io
      expect(@log_output.readlines.join).to eq(
"Creating a backup at \"/backup/dir\"
W: Cannot create backup. The folder /backup/dir already exists and is not empty.
")
    end

    it 'should create backup if force passed' do
      expect(io).to receive(:exist?).with('/backup/dir').ordered.and_return true
      expect(io).to receive(:entries).with('/backup/dir').ordered.and_return ['a']
      expect(io).to receive(:mkdir_p).with('/backup/dir')
      expect(io).to receive(:write).with('/backup/dir/backups.rb', Templates::backups)
      expect(io).to receive(:write).with('/backup/dir/sync.rb', Templates::sync)

      Backups::create_backup '/backup/dir', ctx.logger, io, force: true
    end
  end

  describe '#discover_packages' do
    it 'should include packages' do
      package = instance_double(Package, has_data: true)
      root_package = ItemPackage.new ctx
      ctx.packages['a'] = package

      expect(Backups::discover_packages root_package).to eq ['a']
    end

    it 'should not include packages with no data' do
      package = ItemPackage.new ctx
      root_package = ItemPackage.new ctx

      ctx.packages['a'] = package

      expect(Backups::discover_packages root_package).to eq []
    end

    it 'should not include already existing packages' do
      package = instance_double(Package, has_data: true, name: 'a')
      root_package = ItemPackage.new ctx
      root_package.items << package

      ctx.packages['a'] = package

      expect(Backups::discover_packages root_package).to eq []
    end

    it 'should not include an already existing nested package' do
      package1 = instance_double(Package, has_data: true, name: 'a')
      package2 = ItemPackage.new ctx
      package2.items << package1
      root_package = ItemPackage.new ctx
      root_package.items << package2

      ctx.packages['a'] = package1

      expect(Backups::discover_packages root_package).to eq []
    end
  end
end

end # module Setup
