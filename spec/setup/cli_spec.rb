# This tests the overall appliction integration test.
require 'setup/cli'
require 'setup/io'

require 'tmpdir'

module Setup

$thor_runner = true

RSpec.describe Cli::AppCLI do
  let(:app_cli)        { Cli::AppCLI.new }
  let(:backup_manager) { instance_double(Setup::BackupManager) }

  describe '#get_io' do
    it { expect(app_cli.get_io).to eq(CONCRETE_IO) }
    it { expect(app_cli.get_io dry: true).to eq(DRY_IO) }
  end

  describe '#get_backups_manager' do
    it 'creates backup manager with default parameters when no options given' do
      expect(Setup::BackupManager).to receive(:new).with(io: CONCRETE_IO, config_path: nil).and_return backup_manager
      expect(backup_manager).to receive(:load).and_return backup_manager
      expect(app_cli.get_backups_manager).to eq(backup_manager)
    end

    it 'creates backup manager with passed in options' do
      expect(Setup::BackupManager).to receive(:new).with(io: DRY_IO, config_path: '/config/path').and_return backup_manager
      expect(backup_manager).to receive(:load).and_return backup_manager
      expect(app_cli.get_backups_manager({ dry: true, config: '/config/path' })).to eq(backup_manager)
    end
  end
end

RSpec.describe Cli::SetupCLI do
  let(:setup_cli)      { Cli::SetupCLI.new }
  let(:backup_manager) { instance_double(Setup::BackupManager) }

  describe '#get_io' do
    it { expect(setup_cli.get_io dry: true).to eq(DRY_IO) }
    it { expect(setup_cli.get_io).to eq(CONCRETE_IO) }
  end

  describe '#get_backups_manager' do
    context 'when default options are given' do
      it 'creates a default backup manager' do
        expect(Setup::BackupManager).to receive(:new).with(io: CONCRETE_IO, config_path: nil).and_return backup_manager
        expect(backup_manager).to receive(:load).and_return backup_manager
        expect(setup_cli.get_backups_manager).to eq(backup_manager)
      end
    end

    context 'when --dry and --config=/config/path' do
      it 'creates backup manager with passed in options' do
        expect(Setup::BackupManager).to receive(:new).with(io: DRY_IO, config_path: '/config/path').and_return backup_manager
        expect(backup_manager).to receive(:load).and_return backup_manager
        expect(setup_cli.get_backups_manager({ dry: true, config: '/config/path' })).to eq(backup_manager)
      end
    end
  end
end

# Integration tests.
RSpec.describe './setup' do
  let(:setup)  { Cli::SetupCLI }
  let(:cmd)    { instance_double(HighLine) }

  def expect_file_content(path, content)
    expect(File.exist? path).to be true
    expect(File.read path).to eq(content)
  end

  def expect_yaml_content(path, yaml_hash)
    expect_file_content path, YAML::dump(yaml_hash)
  end

  def save_file_content(path, content)
    FileUtils.mkdir_p File.dirname path
    File.write path, content
  end

  # Saves a yaml content somewhere.
  def save_yaml_content(path, yaml_hash)
    save_file_content path, YAML::dump(yaml_hash)
  end

  # Creates a base directory setup.
  # Creates the applications folder and a sample task.
  def create_base_setup
    FileUtils.mkdir_p File.join(@tmpdir, 'apps')
    FileUtils.mkdir_p File.join(@tmpdir, 'machine')

    save_file_content File.join(@tmpdir, 'machine/vim/.vimrc'), '; Vim configuration.'
    save_yaml_content File.join(@tmpdir, 'apps/vim.yml'), 'name' => 'vim', 'files' => ['vim/.vimrc']
  end

  # Create a temporary folder where the test should sync data data.
  around(:each) do |example|
    Dir.mktmpdir do |tmpdir|
      @tmpdir = tmpdir
      example.call
    end
  end

  # Override app constants to redirect the sync to temp folders.
  before(:each) do
    @applications_dir      = File.join(@tmpdir, 'apps')
    @default_config_root   = File.join(@tmpdir, 'setup.yml')
    @default_restore_root  = File.join(@tmpdir, 'machine')
    @default_backup_root   = File.join(@tmpdir, 'dotfiles')
    @default_backup_dir    = File.join(@tmpdir, 'dotfiles/local')
    @default_backup_config = File.join(@tmpdir, 'dotfiles/local/config.yml')

    stub_const 'Setup::Backup::APPLICATIONS_DIR', @applications_dir
    stub_const 'Setup::BackupManager::DEFAULT_CONFIG_PATH', @default_config_root
    stub_const 'Setup::BackupManager::DEFAULT_RESTORE_ROOT', @default_restore_root
    stub_const 'Setup::Backup::DEFAULT_BACKUP_ROOT', @default_backup_root
    stub_const 'Setup::Backup::DEFAULT_BACKUP_DIR', @default_backup_dir

    # Take over the interactions with console in order to stub out user interaction.
    stub_const 'Setup::Cli::Commandline', cmd

    create_base_setup
  end

  describe '--help' do
    it { capture(:stdout) { setup.start %w[--help] } }
  end

  describe 'init' do

    it 'should clone repositories'

    # TODO: simplify the checks since all of them follow a similar pattern?
    context 'when no options are passed in' do
      it 'should prompt by default' do
        expect(cmd).to receive(:agree).once.and_return true
        setup.start %w[init]

        expect_yaml_content @default_config_root, 'backups' => [@default_backup_dir]
        expect_yaml_content @default_backup_config, 'enabled_task_names' => ['vim'], 'disabled_task_names' => []
      end
    end

    context 'when --enable_new=prompt' do
      it 'should create a local backup and enable tasks if user replies y to prompt' do
        expect(cmd).to receive(:agree).once.and_return true
        setup.start %w[init --enable_new=prompt]

        expect_yaml_content @default_config_root,'backups' => [@default_backup_dir]
        expect_yaml_content @default_backup_config,'enabled_task_names' => ['vim'], 'disabled_task_names' => []
      end

      it 'should create a local backup and disable tasks if user replies n to prompt' do
        expect(cmd).to receive(:agree).once.and_return false
        setup.start %w[init --enable_new=prompt]

        expect_yaml_content @default_config_root,'backups' => [@default_backup_dir]
        expect_yaml_content @default_backup_config,'enabled_task_names' => [], 'disabled_task_names' => ['vim']
      end
    end

    context 'when --enable_new=all' do
      it 'should create a local backup and enable found tasks' do
        setup.start %w[init --enable_new=all]

        expect_yaml_content @default_config_root,'backups' => [@default_backup_dir]
        expect_yaml_content @default_backup_config,'enabled_task_names' => ['vim'], 'disabled_task_names' => []
      end
    end

    context 'when --enable_new=none' do
      it 'should create a local backup and disable found tasks' do
        setup.start %w[init --enable_new=none]

        expect_yaml_content @default_config_root,'backups' => [@default_backup_dir]
        expect_yaml_content @default_backup_config,'enabled_task_names' => [], 'disabled_task_names' => ['vim']
      end
    end

    context 'when --dir=./custom/path' do
      it 'should not affect default path'
      it 'should not affect relative path'
      it 'should not affect absolute path'
      it 'should create a backup relative to the new dir'
    end

    context 'when global config already exists' do
      it 'should append to the config' do
        example_dir = File.join(@tmpdir, 'lollipop')
        example_config = File.join(example_dir, 'config.yml')
        save_yaml_content @default_config_root, 'backups' => [example_dir]
        setup.start %w[init --enable_new=all]

        expect_yaml_content @default_config_root, 'backups' => [example_dir, @default_backup_dir]
        expect_yaml_content @default_backup_config, 'enabled_task_names' => ['vim'], 'disabled_task_names' => []
        expect_yaml_content example_config, 'enabled_task_names' => ['vim'], 'disabled_task_names' => []
      end
    end

    context 'when a folder to init already exists' do
      it 'should fail init' do
        save_file_content @default_backup_config, 'not a yaml file'
        setup.start %w[init --enable_new=all]

        expect(File.exist? @default_config_root).to be false
        expect_file_content @default_backup_config, 'not a yaml file'
      end
    end

    context 'when the global config file is invalid' do
      it 'should print an error message' do
        save_file_content @default_config_root, '---blah'
        setup.start %w[init --enable_new=all]

        expect_file_content @default_config_root, '---blah'
        expect(File.exist? @default_backup_config).to be false
      end
    end
  end

  describe 'backup' do
    it 'should backup'

    context 'when --copy=true' do
      it 'should generate file copies instead of symlinks'
    end

    context 'when the backup config file is invalid' do
      it 'should print an error message'
    end

    context 'when a task config is invalid' do
      it 'should print an error message'
    end
  end

  describe 'restore' do
    it 'should restore'

    context 'when --copy=true' do
      it 'should generate file copies instead of symlinks'
    end

    context 'when the backup config file is invalid' do
      it 'should print an error message'
    end

    context 'when a task config is invalid' do
      it 'should print an error message'
    end
  end

  describe 'cleanup' do

    it 'should cleanup old backups'

    context 'when no options are passed in' do
      it 'should require confirmation'
    end

    context 'when --confirm=false' do
      it 'should skip confirmation'
    end
  end

  describe 'status' do
    it 'should print status'
  end

  describe 'app' do
    describe 'add' do
      it 'should add apps'
    end

    describe 'remove' do
      it 'should remove apps'
    end

    describe 'list' do
      it 'should list apps ready to be add/remove'
    end
  end
end

end # module Setup
