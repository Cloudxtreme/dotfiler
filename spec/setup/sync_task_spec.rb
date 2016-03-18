# Tests file_backup.rb

require 'setup/sync_task'
require 'setup/io'

module Setup

RSpec.describe 'SyncTask' do
  let(:io) { instance_double('File_IO') }
  let(:host_info) { { label: '<win>', restore_root: '/restore/root', backup_root: '/backup/root', sync_time: 'sync_time' } }
  let(:resolver) { instance_double('SyncTaskResolver') }

  def get_sync_task(config, expected_sync_items)
    sync_items = expected_sync_items.map do |sync_item|
      sync_item[:backup_path] = File.expand_path(sync_item[:backup_path]) if sync_item[:backup_path]
      sync_item[:restore_path] = File.expand_path(sync_item[:restore_path]) if sync_item[:restore_path]
      item = instance_double('FileSync')
      expect(FileSync).to receive(:new).with('sync_time', io).and_return item
      item
    end
    [SyncTask.new(config, host_info, io), sync_items]
  end

  describe 'initialize' do
    it 'use configuration name' do
      expect(SyncTask.new({}, {}, io).name).to be_nil
      expect(SyncTask.new({'name' => 'name'}, {}, io).name).to eq('name')
    end

    it 'should execute if plaform is fulfilled' do
      expect(SyncTask.new({}, {}, io).should_execute).to be true
      expect(SyncTask.new({'platforms' => nil}, {}, io).should_execute).to be true
      expect(SyncTask.new({'platforms' => []}, {}, io).should_execute).to be true
      expect(SyncTask.new({'platforms' => []}, {label: '<lin>'}, io).should_execute).to be true
      expect(SyncTask.new({'platforms' => ['<lin>']}, {label: '<lin>'}, io).should_execute).to be true
      expect(SyncTask.new({'platforms' => ['<lin>', '<mac>']}, {label: '<lin>'}, io).should_execute).to be true
    end

    it 'should not execute if platform is not fulfilled' do
      expect(SyncTask.new({'platforms' => ['<lin>']}, {}, io).should_execute).to be false
      expect(SyncTask.new({'platforms' => ['<lin>']}, {label: '<win>'}, io).should_execute).to be false
    end

    it 'should not create sync objects if files missing' do
      expect(FileSync).to_not receive(:new)
      SyncTask.new({'name' => 'task', 'files' => []}, host_info, io)
    end

    it 'should generate sync items' do
      task_config = {'name' => 'task', 'files' => ['a']}
      expected_sync_items = [{backup_path: '/backup/root/task/a', restore_path: '/restore/root/a'}]
      get_sync_task(task_config, expected_sync_items)

      task_config = {'name' => 'task', 'files' => ['a', 'b']}
      expected_sync_items = [
        {backup_path: '/backup/root/task/a', restore_path: '/restore/root/a'},
        {backup_path: '/backup/root/task/b', restore_path: '/restore/root/b'}]
      get_sync_task(task_config, expected_sync_items)

      backup_path, restore_path = File.expand_path('/a'), File.expand_path('/b')
      task_config = {'name' => 'task', 'files' => [{backup_path: backup_path, restore_path: restore_path}]}
      expected_sync_items = [{backup_path: backup_path, restore_path: restore_path}]
      get_sync_task(task_config, expected_sync_items)

      pending 'complete this scenario with improved string expansion'
      raise 'handle string input'
    end

    it 'should skip sync items with different labels' do
      task_config = {'name' => 'task', 'files' => [{'<lin>' => 'a'}]}
      expected_sync_items = []
      get_sync_task(task_config, expected_sync_items)

      task_config = {'name' => 'task', 'files' => [{'<win>' => 'a'}]}
      expected_sync_items = [{backup_path: '/backup/root/task/a', restore_path: '/restore/root/a'}]
      get_sync_task(task_config, expected_sync_items)
    end
  end

  it 'should forward the message to all sync items' do
    task_config = {'name' => 'task', 'files' => ['a']}
    options = {backup_path: '/backup/root/task/a', restore_path: '/restore/root/a'}
    expected_sync_items = [options]

    sync_task, sync_items = get_sync_task(task_config, expected_sync_items)
    sync_items.each { |item, _| expect(item).to receive(:backup!).with(options).once }
    sync_task.backup!

    sync_task, sync_items = get_sync_task(task_config, expected_sync_items)
    sync_items.each { |item, _| expect(item).to receive(:restore!).with(options).once }
    sync_task.restore!

    sync_task, sync_items = get_sync_task(task_config, expected_sync_items)
    sync_items.each { |item, _| expect(item).to receive(:reset!).once }
    sync_task.reset!

    sync_task, sync_items = get_sync_task(task_config, expected_sync_items)
    sync_items.each { |item, _| expect(item).to receive(:cleanup).once }
    sync_task.cleanup

    sync_task, sync_items = get_sync_task(task_config, expected_sync_items)
    sync_items.each { |item, _| expect(item).to receive(:info).once }
    sync_task.info
  end
  
  describe 'escape_dotfile_path' do
    it 'should not escape regular files' do
      expect(SyncTask.escape_dotfile_path 'file_path').to eq('file_path')
      expect(SyncTask.escape_dotfile_path '_file_path').to eq('_file_path')
      expect(SyncTask.escape_dotfile_path 'dir/file_path').to eq('dir/file_path')
    end

    it 'should not escape regular files with extensions' do
      expect(SyncTask.escape_dotfile_path 'file_path.ext').to eq('file_path.ext')
      expect(SyncTask.escape_dotfile_path 'file_path.ext1.ext2').to eq('file_path.ext1.ext2')
      expect(SyncTask.escape_dotfile_path 'dir.e/file_path.ext1.ext2').to eq('dir.e/file_path.ext1.ext2')
    end

    it 'should escape dot files' do
      expect(SyncTask.escape_dotfile_path '.file_path').to eq('_file_path')
      expect(SyncTask.escape_dotfile_path 'dir/.file_path').to eq('dir/_file_path')
      expect(SyncTask.escape_dotfile_path '.dir.dir/dir.dir/.file_path.ext').to eq('_dir.dir/dir.dir/_file_path.ext')
    end
  end

  # Test that configuration is correctly resolved.
  describe 'resolve_sync_item_config' do
    it 'should obey labels' do
    end
  end
end

end # module Setup
