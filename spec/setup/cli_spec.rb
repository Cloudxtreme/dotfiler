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
      expect(app_cli.get_backups_manager).to eq(backup_manager)
    end

    it 'creates backup manager with passed in options' do
      expect(Setup::BackupManager).to receive(:new).with(io: DRY_IO, config_path: '/config/path').and_return backup_manager
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
    it 'creates backup manager with default parameters when no options given' do
      expect(Setup::BackupManager).to receive(:new).with(io: CONCRETE_IO, config_path: nil).and_return backup_manager
      expect(setup_cli.get_backups_manager).to eq(backup_manager)
    end

    it 'creates backup manager with passed in options' do
      expect(Setup::BackupManager).to receive(:new).with(io: DRY_IO, config_path: '/config/path').and_return backup_manager
      expect(setup_cli.get_backups_manager({ dry: true, config: '/config/path' })).to eq(backup_manager)
    end
  end

  describe 'get_tasks' do
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

  def expect_yaml_content(path, content)
    expect(File.exist? path).to be true
    expect(File.read path).to eq(YAML::dump(content))
  end

  # Creates a base directory setup.
  # Creates the applications folder and a sample task.
  def create_base_setup(dir)
    FileUtils.mkdir_p File.join(dir, 'apps')
    FileUtils.mkdir_p File.join(dir, 'machine')
    FileUtils.mkdir_p File.join(dir, 'machine/vim')
    File.write File.join(dir, 'machine/vim/.vimrc'), '; Vim configuration.'

    File.write File.join(dir, 'apps/vim.yml'),
      "---\n" \
      "name: vim\n" \
      "files:\n" \
      "- vim/.vimrc\n"
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
    stub_const 'Setup::Cli::Commandline', cmd

    create_base_setup @tmpdir
  end

  describe './setup --help' do
    it { capture(:stdout) { setup.start %w[--help] } }
  end

  describe './setup init' do

    # TODO: simplify the checks since all of them follow a similar pattern?
    it 'should prompt by default' do
      expect(cmd).to receive(:agree).and_return true
      setup.start %w[init]

      expect_yaml_content @default_config_root, 'backups' => [@default_backup_dir]
      expect_yaml_content @default_backup_config, 'enabled_task_names' => ['vim'], 'disabled_task_names' => []
    end

    context 'when --enable_new=prompt' do
      it 'should create a local backup and enable tasks if user replies y to prompt' do
        expect(cmd).to receive(:agree).and_return true
        setup.start %w[init --enable_new=prompt]

        expect_yaml_content @default_config_root,'backups' => [@default_backup_dir]
        expect_yaml_content @default_backup_config,'enabled_task_names' => ['vim'], 'disabled_task_names' => []
      end

      it 'should create a local backup and disable tasks if user replies n to prompt' do
        expect(cmd).to receive(:agree).and_return false
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

    it 'should skip a local backup if one already exists'

    it 'should handle invalid global config file'

    it 'should handle invalid backup config file'

    it 'should handle invalid task config file'

    it 'should allow to pass in a backup folder'

    it 'should clone repositories'
  end

  describe './setup backup' do
  end

  describe './setup restore' do
  end

  describe './setup cleanup' do
    it 'should require confirmation by default'

    it 'should cleanup old backups'

    context '--confirm=false' do
      it 'should skip confirmation'
    end
  end

  describe './setup status' do
    it 'should print status'
  end

  describe './setup app' do
    describe './setup app add' do
    end

    describe './setup app remove' do
    end

    describe './setup app list' do
    end
  end
end

end # module Setup
