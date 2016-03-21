require 'setup/backups'

require 'pathname'
require 'yaml/store'

module Setup

RSpec.describe Backup do
  let(:io)            { instance_double(InputOutput::File_IO) }
  let(:store_factory) { class_double(YAML::Store) }
  let(:backup_store)  { instance_double(YAML::Store) }
  let(:host_info)     { { test_info: true } }
  let(:local_task_a)  { instance_double(SyncTask) }
  let(:local_task_c)  { instance_double(SyncTask) }
  let(:local_task_d)  { instance_double(SyncTask) }
  let(:app_task_a)    { instance_double(SyncTask) }
  let(:app_task_b2)   { instance_double(SyncTask) }
  let(:local_tasks)   { { 'a.yml' => local_task_a, 'b' => '', 'c.yml' => local_task_c, 'd.yml' => local_task_d, '.' => '' } }
  let(:app_tasks)     { { 'a.yml' => app_task_a, 'b2.yml' => app_task_b2, 'invalid.yml' => '---', 'invalid2.yml' => '' } }

  def mock_tasks(tasks_dir, tasks)
    return if tasks.empty?

    backup_dir = Pathname('/backup/dir')

    allow(io).to receive(:entries).with(Pathname(tasks_dir)).and_return tasks.keys
    tasks.map do |task_path, task|
      full_task_path = Pathname(tasks_dir).join(task_path)
      full_host_info = host_info.merge backup_root: backup_dir.to_s
      config = { 'path' => full_task_path.to_s }

      if task.is_a? String
        allow(io).to receive(:read).with(full_task_path).and_return task
      else
        allow(io).to receive(:read).with(full_task_path).and_return YAML::dump(config)
        allow(SyncTask).to receive(:new).with(config, full_host_info, io).and_return task
      end
    end
  end

  def get_backup(local_tasks, app_tasks, enabled_tasks, disabled_tasks)
    expect(io).to receive(:exist?).with(Pathname('/backup/dir/_tasks')).and_return (not local_tasks.empty?)
    expect(io).to receive(:exist?).with(Pathname(Backup::APPLICATIONS_DIR)).and_return (not app_tasks.empty?)
    expect(store_factory).to receive(:new).and_return backup_store
    expect(backup_store).to receive(:transaction).with(true).and_yield backup_store
    expect(backup_store).to receive(:fetch).with('enabled_task_names', []).and_return enabled_tasks
    expect(backup_store).to receive(:fetch).with('disabled_task_names', []).and_return disabled_tasks

    mock_tasks '/backup/dir/_tasks', local_tasks
    mock_tasks Backup::APPLICATIONS_DIR, app_tasks

    Backup.new '/backup/dir', host_info, io, store_factory
  end

  describe '#initialize' do
    it 'should initialize from config files' do
      backup = get_backup({}, {}, ['a', 'b'], ['c', 'd'])
      expect(backup.enabled_task_names).to eq(Set.new ['a', 'b'])
      expect(backup.disabled_task_names).to eq(Set.new ['c', 'd'])
      expect(backup.tasks).to eq({})
    end

    it 'should skip tasks when yaml file is empty' do
      backup = get_backup({'a.yml' => ''}, {}, ['a'], [])
      expect(backup.tasks).to eq({})
    end

    it 'should skip tasks with invalid yaml file' do
      backup = get_backup({'a.yml' => '---'}, {}, ['a'], [])
      expect(backup.tasks).to eq({})
    end

    it 'should intiialize tasks' do
      backup = get_backup(local_tasks, app_tasks, [], [])
      expect(backup.tasks).to eq({ 'a' => local_task_a, 'b2' => app_task_b2, 'c' => local_task_c, 'd' => local_task_d })
      expect(backup.enabled_task_names).to eq(Set.new [])
      expect(backup.disabled_task_names).to eq(Set.new [])
    end
  end

  def verify_backup_save(backup, update_names, expected_task_names)
    if not Set.new(update_names).intersection(Set.new(backup.tasks.keys)).empty?
      expect(backup_store).to receive(:transaction).with(no_args).and_yield backup_store
      expect(backup_store).to receive(:[]=).with('enabled_task_names', expected_task_names[:enabled])
      expect(backup_store).to receive(:[]=).with('disabled_task_names', expected_task_names[:disabled])
    end
  end

  def assert_enable_tasks(initial_task_names, enabled_task_names, expected_task_names)
    backup = get_backup(local_tasks, app_tasks, initial_task_names[:enabled], initial_task_names[:disabled])
    verify_backup_save(backup, enabled_task_names, expected_task_names)

    backup.enable_tasks enabled_task_names
    expect(backup.enabled_task_names).to eq(Set.new expected_task_names[:enabled])
    expect(backup.disabled_task_names).to eq(Set.new expected_task_names[:disabled])
  end

  def assert_disable_tasks(initial_task_names, disabled_task_names, expected_task_names)
    backup = get_backup(local_tasks, app_tasks, initial_task_names[:enabled], initial_task_names[:disabled])
    verify_backup_save(backup, disabled_task_names, expected_task_names)

    backup.disable_tasks disabled_task_names
    expect(backup.enabled_task_names).to eq(Set.new expected_task_names[:enabled])
    expect(backup.disabled_task_names).to eq(Set.new expected_task_names[:disabled])
  end

  describe '#enable_tasks' do
    it { assert_enable_tasks({enabled: [], disabled: []}, [], {enabled: [], disabled: []}) }
    it { assert_enable_tasks({enabled: [], disabled: []}, ['task1', 'task2'], {enabled: [], disabled: []}) }
    it { assert_enable_tasks({enabled: [], disabled: []}, ['a'], {enabled: ['a'], disabled: []}) }
    it { assert_enable_tasks({enabled: [], disabled: []}, ['A', 'b2'], {enabled: ['a', 'b2'], disabled: []}) }
    it { assert_enable_tasks({enabled: ['a'], disabled: []}, ['A', 'b2'], {enabled: ['a', 'b2'], disabled: []}) }
    it { assert_enable_tasks({enabled: ['a'], disabled: ['b2', 'c']}, ['A', 'b2'], {enabled: ['a', 'b2'], disabled: ['c']}) }
  end

  describe '#disable_tasks' do
    it { assert_disable_tasks({enabled: [], disabled: []}, [], {enabled: [], disabled: []}) }
    it { assert_disable_tasks({enabled: [], disabled: []}, ['task1', 'task2'], {enabled: [], disabled: []}) }
    it { assert_disable_tasks({enabled: [], disabled: []}, ['a'], {enabled: [], disabled: ['a']}) }
    it { assert_disable_tasks({enabled: [], disabled: []}, ['A', 'b2'], {enabled: [], disabled: ['a', 'b2']}) }
    it { assert_disable_tasks({enabled: ['a'], disabled: []}, ['A', 'b2'], {enabled: [], disabled: ['a', 'b2']}) }
    it { assert_disable_tasks({enabled: ['a', 'c'], disabled: ['b2']}, ['A', 'b2'], {enabled: ['c'], disabled: ['b2', 'a']}) }
  end

  describe '#new_tasks' do
    it 'should include tasks not added to the enabled and disabled tasks that have data' do
      backup = get_backup(local_tasks, app_tasks, ['a'], ['D'])
      expect(local_task_c).to receive(:should_execute).and_return true
      expect(local_task_c).to receive(:has_data).and_return true
      expect(app_task_b2).to receive(:should_execute).and_return true
      expect(app_task_b2).to receive(:has_data).and_return true
      expect(backup.new_tasks).to eq({ 'c' => local_task_c, 'b2' => app_task_b2 })
    end

    it 'should not include tasks with no data' do
      backup = get_backup(local_tasks, app_tasks, ['a'], ['d', 'b2'])
      expect(local_task_c).to receive(:should_execute).and_return true
      expect(local_task_c).to receive(:has_data).and_return false
      expect(backup.new_tasks).to eq({})
    end

    it 'should not include tasks with not matching platform' do
      backup = get_backup(local_tasks, app_tasks, ['a'], ['d', 'b2'])
      expect(local_task_c).to receive(:should_execute).and_return false
      expect(backup.new_tasks).to eq({})
    end
  end

  describe '#tasks_to_run' do
    it 'should include an enabled task with matching platform' do
      backup = get_backup(local_tasks, app_tasks, ['a', 'b'], [])
      expect(local_task_a).to receive(:should_execute).and_return true
      expect(backup.tasks_to_run).to eq({ 'a' => local_task_a })

      backup = get_backup(local_tasks, app_tasks, ['A', 'B'], [])
      expect(local_task_a).to receive(:should_execute).and_return true
      expect(backup.tasks_to_run).to eq({ 'a' => local_task_a })

      backup = get_backup(local_tasks, app_tasks, ['a'], [])
      expect(local_task_a).to receive(:should_execute).and_return false
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
      assert_resolve_backup 'github.com/username/path', '~/dotfiles/github.com/username/path', 'github.com/username/path'
    end

    it 'should allow to specify both local and global path' do
      assert_resolve_backup '~/dotfiles:github.com/username/path', '~/dotfiles', 'github.com/username/path'
      assert_resolve_backup '~/dotfiles:github.com:80/username/path', '~/dotfiles', 'github.com:80/username/path'
    end

    it 'should allow to specify the directory' do
      assert_resolve_backup 'github.com/username/path',
        '~/backups/github.com/username/path', 'github.com/username/path',
        backup_dir: File.expand_path('~/backups/')
    end
  end
end

RSpec.describe BackupManager do
  let(:io)             { instance_double(InputOutput::File_IO) }
  let(:host_info)      { { test_info: true } }
  let(:store_factory)  { class_double(YAML::Store) }
  let(:manager_store)  { instance_double(YAML::Store) }
  let(:backup_store1)  { instance_double(YAML::Store) }
  let(:backup_store2)  { instance_double(YAML::Store) }
  let(:backup1)        { instance_double(Backup) }
  let(:backup2)        { instance_double(Backup) }

  let(:backup_manager) do
    allow(manager_store).to receive(:transaction).and_yield(manager_store)
    allow(backup_store1).to receive(:transaction).and_yield(backup_store1)
    allow(backup_store2).to receive(:transaction).and_yield(backup_store1)
    expect(store_factory).to receive(:new).with('/config/').and_return manager_store
    BackupManager.new io: io, host_info: host_info, store_factory: store_factory, config_path: '/config/'
  end

  describe '#get_backups' do
    it 'should get no backups if the file is missing' do
      expect(manager_store).to receive(:fetch).with('backups', []).and_return []

      expect(backup_manager.get_backups).to eq([])
    end

    it 'should create backups from their dirs' do
      expect(manager_store).to receive(:fetch).with('backups', []).and_return ['/backup/dir']
      expect(Backup).to receive(:new).with('/backup/dir', host_info, io, store_factory).and_return 'backup'

      expect(backup_manager.get_backups).to eq(['backup'])
    end
  end

  describe '#create_backup' do
    it 'should not create backup if already added to the manager' do
      expect(manager_store).to receive(:fetch).with('backups', []).and_return ['/existing/backup/']

      expected_output = 'Backup "/existing/backup/" already exists.' + "\n"
      expect(capture(:stdout) { backup_manager.create_backup ['/existing/backup/', nil] }).to eq(expected_output)
    end

    it 'should not create backup if backup directory is not empty' do
      expect(manager_store).to receive(:fetch).with('backups', []).and_return ['/existing/backup/']
      expect(io).to receive(:exist?).with('/backup/dir').and_return true
      expect(io).to receive(:entries).with('/backup/dir').and_return ['a']

      expected_output = 'Cannot create backup. The folder /backup/dir already exists and is not empty.' + "\n"
      expect(capture(:stdout) { backup_manager.create_backup ['/backup/dir', nil] }).to eq(expected_output)
    end

    it 'should update configuration file if directory already present' do
      expect(manager_store).to receive(:fetch).with('backups', []).and_return ['/existing/backup/']
      expect(io).to receive(:exist?).with('/backup/dir').and_return true
      expect(io).to receive(:entries).with('/backup/dir').and_return []
      expect(manager_store).to receive(:fetch).with('backups', []).and_return ['/existing/backup/']
      expect(manager_store).to receive(:[]=).with('backups', ['/existing/backup/', '/backup/dir']).and_return ['/backup/dir']

      backup_manager.create_backup ['/backup/dir', nil]
    end

    it 'should clone the repository if source present' do
      expect(manager_store).to receive(:fetch).with('backups', []).and_return ['/existing/backup/']
      expect(io).to receive(:exist?).with('/backup/dir').and_return true
      expect(io).to receive(:entries).with('/backup/dir').and_return []
      expect(io).to receive(:shell).with('git clone "example.com/username/dotfiles" -o "/backup/dir"')
      expect(manager_store).to receive(:fetch).with('backups', []).and_return ['/existing/backup/']
      expect(manager_store).to receive(:[]=).with('backups', ['/existing/backup/', '/backup/dir']).and_return ['/backup/dir']

      backup_manager.create_backup ['/backup/dir', 'example.com/username/dotfiles']
    end

    it 'should create the folder if missing' do
      expect(manager_store).to receive(:fetch).with('backups', []).and_return ['/existing/backup/']
      expect(io).to receive(:exist?).with('/backup/dir').and_return false
      expect(io).to receive(:mkdir_p).with('/backup/dir')
      expect(manager_store).to receive(:fetch).with('backups', []).and_return ['/existing/backup/']
      expect(manager_store).to receive(:[]=).with('backups', ['/existing/backup/', '/backup/dir']).and_return ['/backup/dir']

      backup_manager.create_backup ['/backup/dir', nil]
    end
  end
end

end # module Setup
