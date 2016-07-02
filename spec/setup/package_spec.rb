# Tests file_backup.rb

require 'setup/package'
require 'setup/platform'
require 'setup/io'

module Setup

RSpec.describe PackageBase do
  let(:io)        { instance_double(InputOutput::File_IO) }
  let(:host_info) { SyncContext.new restore_to: '/restore/root', backup_root: '/backup/root', sync_time: 'sync_time', io: io }
  let(:linctx)    { SyncContext.new restore_to: '/files', backup_root: '/backup/root/Package', sync_time: 'sync_time', io: io }
  let(:winctx)    { SyncContext.new restore_to: '/windows/files', backup_root: '/backup/root/Package', sync_time: 'sync_time', io: io }

  let(:package_class) do
    Class.new(PackageBase) do
      name 'Package'
      platforms [:WINDOWS]
      under_windows { restore_to '/windows/files' }
      under_linux   { restore_to '/files'}

      def steps
        under_linux { file '.unknown' }
      end
    end
  end

  let(:package) { package_class.new(host_info) }
  let(:default_package) { PackageBase.new(host_info) }

  describe 'default package' do
    it 'should have an empty name' do
      expect(default_package.name).to eq('')
      expect(default_package.platforms).to eq []
      expect(default_package.should_execute).to be true
    end
  end

  it 'should work under the same platform' do
    under_windows do
      expect(package.name).to eq('Package')
      expect(package.restore_to).to eq('/windows/files')
      expect(package.should_execute).to be true
      expect(package.sync_items).to eq []
    end
  end

  it 'should not work under a different platform' do
    under_linux do
      expect(package.name).to eq('Package')
      expect(package.restore_to).to eq('/files')
      expect(package.should_execute).to be false
      expect(package.sync_items).to match_array [an_instance_of(FileSyncTask)]
      expect(package.sync_items[0].name).to eq '.unknown'
      expect(package.sync_items[0].file_sync_options).to eq({
        name: '.unknown',
        backup_path: linctx.backup_path('_unknown'),
        restore_path: linctx.restore_path('.unknown') })
    end
  end

  it 'should allow skipping' do
    under_windows do
      package.skip 'just because'
      expect(package.should_execute).to eq(false)
      expect(package.skip_reason).to eq('just because')
    end
  end

  it 'should allow adding sync items' do
    under_windows do
      package.file('.another')
      package.file('.another2').save_as('_anotherTwo')
      expect(package.sync_items).to match_array [an_instance_of(FileSyncTask), an_instance_of(FileSyncTask)]
      expect(package.sync_items[0].name).to eq('.another')
      expect(package.sync_items[0].file_sync_options).to eq({
        name: '.another',
        backup_path: winctx.backup_path('_another'),
        restore_path: winctx.restore_path('.another') })

      expect(package.sync_items[1].name).to eq('.another2')
      expect(package.sync_items[1].file_sync_options).to eq({
        name: '.another2',
        backup_path: winctx.backup_path('_anotherTwo'),
        restore_path: winctx.restore_path('.another2') })
    end
  end
end

RSpec.describe Package do
  let(:io)        { instance_double(InputOutput::File_IO) }
  let(:platform)  { Platform::label_from_platform }
  let(:host_info) { SyncContext.new restore_to: '/restore/root', backup_root: '/backup/root', sync_time: 'sync_time', io: io }
  let(:ctx)       { SyncContext.new restore_to: '/restore/root/task', backup_root: '/backup/root/task', sync_time: 'sync_time', io: io }

  # Creates a new package with a given config and mocked host_info, io.
  # Asserts that sync_items are created with expected_sync_options.
  def get_package(config, expected_sync_options, options = {})
    sync_items = expected_sync_options.map do |sync_item|
      filepath, sync_options, save_as = sync_item
      info = instance_double('FileSyncInfo', backup_path: ctx.backup_path(save_as || filepath))
      item = instance_double('FileSyncTask', info: info)
      expect(FileSyncTask).to receive(:create).with(filepath, sync_options, an_instance_of(SyncContext)).and_return item
      expect(item).to receive(:save_as).with(save_as).and_return(item) if not save_as.nil?
      item
    end

    package = Package.new(config, host_info.with_options(options))

    expect(package.sync_items).to eq(sync_items)

    [package, sync_items]
  end

  def restore(path)
    File.expand_path "/restore/root/#{path}"
  end

  def backup(path)
    File.expand_path "/backup/root/task/#{path}"
  end

  def config(files)
    { 'name' => 'task', 'files' => files }
  end

  def assert_sync_items(files, expected_sync_options)
    task_config = config files
    get_package task_config, expected_sync_options
  end

  describe 'initialize' do
    it 'use configuration name' do
      expect(Package.new({}, SyncContext.new({})).name).to eq('')
      expect(Package.new({'name' => 'name'}, SyncContext.new({})).name).to eq('name')
    end

    it 'should execute if plaform is fulfilled' do
      expect(Package.new({}, SyncContext.new({})).should_execute).to be true
      expect(Package.new({'platforms' => nil}, SyncContext.new({})).should_execute).to be true
      expect(Package.new({'platforms' => []}, SyncContext.new({})).should_execute).to be true
      under_linux { expect(Package.new({'platforms' => []}, SyncContext.new({})).should_execute).to be true }
      under_linux { expect(Package.new({'platforms' => ['<linux>']}, SyncContext.new({})).should_execute).to be true }
      under_linux { expect(Package.new({'platforms' => ['<linux>', '<macos>']}, SyncContext.new({})).should_execute).to be true }
      under_macos { expect(Package.new({'platforms' => ['<linux>', '<macos>']}, SyncContext.new({})).should_execute).to be true }
    end

    it 'should not execute if platform is not fulfilled' do
      under_windows { expect(Package.new({'platforms' => ['<linux>']}, SyncContext.new({})).should_execute).to be false }
      under_windows { expect(Package.new({'platforms' => ['<linux>']}, SyncContext.new({})).should_execute).to be false }
    end

    it 'should not create sync objects if files missing' do
      expect(FileSync).to_not receive(:new)
      Package.new({'name' => 'task', 'files' => []}, host_info)
    end

    it 'should generate sync items' do
      assert_sync_items ['a'], [['a', {}]]

      assert_sync_items ['a', 'b'], [['a', {}], ['b', {}]]

      backup_path, restore_path = File.expand_path('/a'), File.expand_path('/b')
      assert_sync_items [{backup_path: backup_path, restore_path: restore_path}], [[restore_path, {}, backup_path]]

      assert_sync_items [{ backup_path: 'bp', restore_path: 'rp' }], [['rp', {}, 'bp']]

      assert_sync_items [{ backup_path: File.expand_path('/bp'), restore_path: File.expand_path('/rp') }], [
        [File.expand_path('/rp'), {}, File.expand_path('/bp')]]
    end
    
    it 'should process string keys' do
      assert_sync_items [{ 'backup_path' => 'a', 'restore_path' => 'b' }], [['b', {}, 'a']]
    end

    it 'should handle labels' do
      assert_sync_items [{ platform => 'b', '<>' => 'c' }], [['b', {}]]

      assert_sync_items [{ backup_path: { platform => 'c' }, restore_path: { platform => 'd' } }], [['d', {}, 'c']]
    end

    it 'should skip sync items with different labels' do
      task_config = config [{'<>' => 'a'}]
      expected_sync_options = []
      get_package(task_config, expected_sync_options)

      task_config = config [{platform => 'a'}]
      expected_sync_options = [['a', {}]]
      get_package(task_config, expected_sync_options)
    end
  end

  it 'should forward the message to all sync items' do
    task_config = config ['a']
    options = [['a', {}]]

    package, sync_items = get_package(task_config, options)
    sync_items.each { |item| expect(item).to receive(:sync!).once }
    package.sync! {}

    package, sync_items = get_package(task_config, options)
    sync_items.each { |item| expect(item).to receive(:info).once }
    package.info
  end

  it 'should find cleanup files' do
    task_config = config ['a']
    expected_sync_options = [['a', {}]]

    package, _ = get_package(task_config, expected_sync_options)
    expect(io).to receive(:glob).twice.with('/backup/root/task/**/*').and_return [
      File.expand_path('/backup/root/task/a'),
      File.expand_path('/backup/root/task/a/file'),
      File.expand_path('/backup/root/task/b'),
      File.expand_path('/backup/root/task/b/subfile'),
      File.expand_path('/backup/root/task/setup-backup-file')]

    expect(package.cleanup).to eq([File.expand_path('/backup/root/task/setup-backup-file')])

    package, _ = get_package(task_config, expected_sync_options, untracked: true)
    expect(package.cleanup).to eq([
      File.expand_path('/backup/root/task/b'),
      File.expand_path('/backup/root/task/setup-backup-file')])
  end
end

end # module Setup
