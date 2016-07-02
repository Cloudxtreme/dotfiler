# Tests file_backup.rb

require 'setup/package'
require 'setup/platform'
require 'setup/io'

module Setup

RSpec.describe 'Package' do
  let(:io)        { instance_double(InputOutput::File_IO) }
  let(:platform)  { Platform::label_from_platform }
  let(:host_info) { SyncContext.new restore_to: '/restore/root', backup_root: '/backup/root', sync_time: 'sync_time', io: io }
  let(:ctx)       { SyncContext.new restore_to: '/restore/root/task', backup_root: '/backup/root/task', sync_time: 'sync_time', io: io }

  # Creates a new package with a given config and mocked host_info, io.
  # Asserts that sync_items are created with expected_sync_options.
  def get_package(config, expected_sync_options, options = {})
    # ctx ||= SyncContext.new
    sync_items = expected_sync_options.map do |sync_item|
      filepath, sync_options, save_as = sync_item
      info = instance_double('FileSyncInfo', backup_path: ctx.backup_path(save_as || filepath))
      item = instance_double('FileSyncTask', info: info)
      expect(FileSyncTask).to receive(:new).with(filepath, sync_options, an_instance_of(SyncContext)).and_return item
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
      expect(Package.new({'platforms' => ['<lin>']}, SyncContext.new({})).should_execute).to be false
      expect(Package.new({'platforms' => ['<lin>']}, SyncContext.new({label: ['<win>']})).should_execute).to be false
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
