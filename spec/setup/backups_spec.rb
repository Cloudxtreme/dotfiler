require 'setup/backups'
require 'setup/sync_context'

require 'pathname'
require 'yaml/store'

module Setup

RSpec.describe Backup do
  let(:io)            { instance_double(InputOutput::File_IO, dry: false) }
  let(:store_factory) { class_double(YAML::Store) }
  let(:backup_store)  { instance_double(YAML::Store, path: '') }
  let(:ctx)           { SyncContext.create(io).with_options test_info: true }
  let(:task_a)        { instance_double(Package) }
  let(:task_c)        { instance_double(Package) }
  let(:task_d)        { instance_double(Package) }
  let(:task_b2)       { instance_double(Package) }
  let(:tasks)         { { 'a' => task_a, 'b2' => task_b2, 'c' => task_c, 'd' => task_d } }

  def get_backup(tasks, enabled_tasks, disabled_tasks)
    backup = Backup.new('/backup/dir', ctx, backup_store)
    backup.enabled_task_names = Set.new enabled_tasks
    backup.disabled_task_names = Set.new disabled_tasks
    backup.tasks = tasks
    backup
  end

  describe '#initialize' do
    it 'should initialize from config files' do
      backup = get_backup({'a' => 12}, ['a', 'b'], ['c', 'd'])
      expect(backup.enabled_task_names).to eq(Set.new ['a', 'b'])
      expect(backup.disabled_task_names).to eq(Set.new ['c', 'd'])
      expect(backup.tasks).to eq({'a' => 12})
    end
  end

  def verify_backup_save(backup, update_names, expected_task_names)
    if not Set.new(update_names).intersection(Set.new(backup.tasks.keys)).empty?
      expect(backup_store).to receive(:transaction).with(false).and_yield backup_store
      expect(backup_store).to receive(:[]=).with('enabled_task_names', expected_task_names[:enabled])
      expect(backup_store).to receive(:[]=).with('disabled_task_names', expected_task_names[:disabled])
    end
  end

  def assert_enable_tasks(initial_task_names, enabled_task_names, expected_task_names)
    backup = get_backup(tasks, initial_task_names[:enabled], initial_task_names[:disabled])
    verify_backup_save(backup, enabled_task_names, expected_task_names)

    backup.enable_tasks! enabled_task_names
    expect(backup.enabled_task_names).to eq(Set.new expected_task_names[:enabled])
    expect(backup.disabled_task_names).to eq(Set.new expected_task_names[:disabled])
  end

  def assert_disable_tasks(initial_task_names, disabled_task_names, expected_task_names)
    backup = get_backup(tasks, initial_task_names[:enabled], initial_task_names[:disabled])
    verify_backup_save(backup, disabled_task_names, expected_task_names)

    backup.disable_tasks! disabled_task_names
    expect(backup.enabled_task_names).to eq(Set.new expected_task_names[:enabled])
    expect(backup.disabled_task_names).to eq(Set.new expected_task_names[:disabled])
  end

  describe '#enable_tasks!' do
    it { assert_enable_tasks({enabled: [], disabled: []}, [], {enabled: [], disabled: []}) }
    it { assert_enable_tasks({enabled: [], disabled: []}, ['task1', 'task2'], {enabled: [], disabled: []}) }
    it { assert_enable_tasks({enabled: [], disabled: []}, ['a'], {enabled: ['a'], disabled: []}) }
    it { assert_enable_tasks({enabled: [], disabled: []}, ['A', 'b2'], {enabled: ['a', 'b2'], disabled: []}) }
    it { assert_enable_tasks({enabled: ['a'], disabled: []}, ['A', 'b2'], {enabled: ['a', 'b2'], disabled: []}) }
    it { assert_enable_tasks({enabled: ['a'], disabled: ['b2', 'c']}, ['A', 'b2'], {enabled: ['a', 'b2'], disabled: ['c']}) }
  end

  describe '#disable_tasks!' do
    it { assert_disable_tasks({enabled: [], disabled: []}, [], {enabled: [], disabled: []}) }
    it { assert_disable_tasks({enabled: [], disabled: []}, ['task1', 'task2'], {enabled: [], disabled: []}) }
    it { assert_disable_tasks({enabled: [], disabled: []}, ['a'], {enabled: [], disabled: ['a']}) }
    it { assert_disable_tasks({enabled: [], disabled: []}, ['A', 'b2'], {enabled: [], disabled: ['a', 'b2']}) }
    it { assert_disable_tasks({enabled: ['a'], disabled: []}, ['A', 'b2'], {enabled: [], disabled: ['a', 'b2']}) }
    it { assert_disable_tasks({enabled: ['a', 'c'], disabled: ['b2']}, ['A', 'b2'], {enabled: ['c'], disabled: ['b2', 'a']}) }
  end

  describe '#new_tasks' do
    it 'should include tasks not added to the enabled and disabled tasks that have data' do
      backup = get_backup(tasks, ['a'], ['D'])
      expect(task_c).to receive(:should_execute).and_return true
      expect(task_c).to receive(:has_data).and_return true
      expect(task_b2).to receive(:should_execute).and_return true
      expect(task_b2).to receive(:has_data).and_return true
      expect(backup.new_tasks).to eq({ 'c' => task_c, 'b2' => task_b2 })
    end

    it 'should not include tasks with no data' do
      backup = get_backup(tasks, ['a'], ['d', 'b2'])
      expect(task_c).to receive(:should_execute).and_return true
      expect(task_c).to receive(:has_data).and_return false
      expect(backup.new_tasks).to eq({})
    end

    it 'should not include tasks with not matching platform' do
      backup = get_backup(tasks, ['a'], ['d', 'b2'])
      expect(task_c).to receive(:should_execute).and_return false
      expect(backup.new_tasks).to eq({})
    end
  end

  describe '#tasks_to_run' do
    it 'should include an enabled task with matching platform' do
      backup = get_backup(tasks, ['a', 'b'], [])
      expect(task_a).to receive(:should_execute).and_return true
      expect(backup.tasks_to_run).to eq({ 'a' => task_a })

      backup = get_backup(tasks, ['A', 'B'], [])
      expect(task_a).to receive(:should_execute).and_return true
      expect(backup.tasks_to_run).to eq({ 'a' => task_a })

      backup = get_backup(tasks, ['a'], [])
      expect(task_a).to receive(:should_execute).and_return false
      expect(backup.tasks_to_run).to eq({})
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
  let(:ctx)            { SyncContext.create(io).with_options test_info: true }
  let(:manager_store)  { instance_double(YAML::Store, path: '') }
  let(:backup_store1)  { instance_double(YAML::Store, path: '') }
  let(:backup_store2)  { instance_double(YAML::Store, path: '') }
  let(:backup1)        { instance_double(Backup) }
  let(:backup2)        { instance_double(Backup) }

  let(:backup_manager) do
    allow(manager_store).to receive(:transaction).and_yield(manager_store)
    allow(backup_store1).to receive(:transaction).and_yield(backup_store1)
    allow(backup_store2).to receive(:transaction).and_yield(backup_store1)
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
