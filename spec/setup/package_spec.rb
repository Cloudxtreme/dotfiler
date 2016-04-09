# Tests file_backup.rb

require 'setup/package'
require 'setup/platform'
require 'setup/io'

module Setup

RSpec.describe 'Package' do
  let(:io)        { instance_double(InputOutput::File_IO) }
  let(:platform)  { Platform::machine_labels[0] }
  let(:host_info) { { label: [platform], restore_root: '/restore/root', backup_root: '/backup/root', sync_time: 'sync_time' } }

  # Creates a new package with a given config and mocked host_info, io.
  # Asserts that sync_items are created with expected_sync_options.
  def get_package(config, expected_sync_options)
    sync_items = expected_sync_options.map do |sync_item|
      info = instance_double('FileSyncInfo', backup_path: sync_item[:backup_path])
      instance_double('FileSync', info: info)
    end
    sync_items.each { |item| expect(FileSync).to receive(:new).with('sync_time', io).and_return item }
    package = Package.new(config, host_info, io)

    expected_sync_items = sync_items.zip(expected_sync_options)
    expect(package.sync_items).to eq(expected_sync_items)

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
      expect(Package.new({}, {}, io).name).to be_nil
      expect(Package.new({'name' => 'name'}, {}, io).name).to eq('name')
    end

    it 'should execute if plaform is fulfilled' do
      expect(Package.new({}, {}, io).should_execute).to be true
      expect(Package.new({'platforms' => nil}, {}, io).should_execute).to be true
      expect(Package.new({'platforms' => []}, {}, io).should_execute).to be true
      expect(Package.new({'platforms' => []}, {label: ['<lin>']}, io).should_execute).to be true
      expect(Package.new({'platforms' => ['<lin>']}, {label: ['<lin>']}, io).should_execute).to be true
      expect(Package.new({'platforms' => ['<lin>', '<mac>']}, {label: ['<lin>']}, io).should_execute).to be true
    end

    it 'should not execute if platform is not fulfilled' do
      expect(Package.new({'platforms' => ['<lin>']}, {}, io).should_execute).to be false
      expect(Package.new({'platforms' => ['<lin>']}, {label: ['<win>']}, io).should_execute).to be false
    end

    it 'should not create sync objects if files missing' do
      expect(FileSync).to_not receive(:new)
      Package.new({'name' => 'task', 'files' => []}, host_info, io)
    end

    it 'should generate sync items' do
      assert_sync_items ['a'], [
        { name: 'a', backup_path: backup('a'), restore_path: restore('a') }]

      assert_sync_items ['a', 'b'], [
        { name: 'a', backup_path: backup('a'), restore_path: restore('a') },
        { name: 'b', backup_path: backup('b'), restore_path: restore('b') }]

      backup_path, restore_path = File.expand_path('/a'), File.expand_path('/b')
      assert_sync_items [{backup_path: backup_path, restore_path: restore_path}], [
        { name: File.expand_path('/b'), backup_path: backup_path, restore_path: restore_path}]

      assert_sync_items [{ backup_path: 'bp', restore_path: 'rp' }], [
        { name: 'rp', backup_path: backup('bp'), restore_path: restore('rp') }]

      assert_sync_items [{ backup_path: File.expand_path('/bp'), restore_path: File.expand_path('/rp') }], [
        { name: File.expand_path('/rp'), backup_path: File.expand_path('/bp'), restore_path: File.expand_path('/rp') }]
    end
    
    it 'should process string keys' do
      assert_sync_items [{ 'backup_path' => 'a', 'restore_path' => 'b' }], [
        { name: 'b', backup_path: backup('a'), restore_path: restore('b') }]
    end

    it 'should handle labels' do
      assert_sync_items [{ platform => 'b', '<>' => 'c' }], [
        { name: 'b', backup_path: backup('b'), restore_path: restore('b') }]

      assert_sync_items [{ backup_path: { platform => 'c' }, restore_path: { platform => 'd' } }], [
        { name: 'd', backup_path: backup('c'), restore_path: restore('d') }]
    end

    it 'should skip sync items with different labels' do
      task_config = config [{'<>' => 'a'}]
      expected_sync_options = []
      get_package(task_config, expected_sync_options)

      task_config = config [{platform => 'a'}]
      expected_sync_options = [
        { name: 'a', backup_path: backup('a'), restore_path: restore('a') }]
      get_package(task_config, expected_sync_options)
    end
  end

  it 'should forward the message to all sync items' do
    task_config = config ['a']
    options = {
      name: 'a',
      backup_path: File.expand_path('/backup/root/task/a'),
      restore_path: File.expand_path('/restore/root/a') }
    expected_sync_options = [options]

    package, sync_items = get_package(task_config, expected_sync_options)
    sync_items.each { |item, _| expect(item).to receive(:sync!).with(options).once }
    package.sync! {}

    package, sync_items = get_package(task_config, expected_sync_options)
    sync_items.each { |item, _| expect(item).to receive(:reset!).once }
    package.reset! {}

    package, sync_items = get_package(task_config, expected_sync_options)
    sync_items.each { |item, _| expect(item).to receive(:info).once }
    package.info

    package, sync_items = get_package(task_config, expected_sync_options)
    sync_items.each { |item, _| expect(item).to receive(:has_data).once }
    package.has_data
  end

  it 'should find cleanup files' do
    task_config = config ['a']
    options = {
      name: 'a',
      backup_path: File.expand_path('/backup/root/task/a'),
      restore_path: File.expand_path('/restore/root/a') }
    expected_sync_options = [options]

    package, _ = get_package(task_config, expected_sync_options)
    expect(io).to receive(:glob).twice.with('/backup/root/task/**/*').and_return [
      File.expand_path('/backup/root/task/a'),
      File.expand_path('/backup/root/task/a/file'),
      File.expand_path('/backup/root/task/b'),
      File.expand_path('/backup/root/task/b/subfile'),
      File.expand_path('/backup/root/task/setup-backup-file')]

    expect(package.cleanup).to eq([File.expand_path('/backup/root/task/setup-backup-file')])
    
    expect(package.cleanup untracked: true).to eq([
      File.expand_path('/backup/root/task/b'),
      File.expand_path('/backup/root/task/setup-backup-file')])
  end

  describe 'escape_dotfile_path' do
    it 'should not escape regular files' do
      expect(Package.escape_dotfile_path 'file_path').to eq('file_path')
      expect(Package.escape_dotfile_path '_file_path').to eq('_file_path')
      expect(Package.escape_dotfile_path 'dir/file_path').to eq('dir/file_path')
    end

    it 'should not escape regular files with extensions' do
      expect(Package.escape_dotfile_path 'file_path.ext').to eq('file_path.ext')
      expect(Package.escape_dotfile_path 'file_path.ext1.ext2').to eq('file_path.ext1.ext2')
      expect(Package.escape_dotfile_path 'dir.e/file_path.ext1.ext2').to eq('dir.e/file_path.ext1.ext2')
    end

    it 'should escape dot files' do
      expect(Package.escape_dotfile_path '.file_path').to eq('_file_path')
      expect(Package.escape_dotfile_path 'dir/.file_path').to eq('dir/_file_path')
      expect(Package.escape_dotfile_path '.dir.dir/dir.dir/.file_path.ext').to eq('_dir.dir/dir.dir/_file_path.ext')
    end
  end
end

end # module Setup
