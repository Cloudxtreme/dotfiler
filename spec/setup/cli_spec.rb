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
  
  def get_backup_manager(options = {})
    actual_manager = nil
    app_cli.with_backup_manager(options) { |backup_manager| actual_manager = backup_manager }
    actual_manager
  end

  describe '#with_backup_manager' do
    it 'creates backup manager with default parameters when no options given' do
      expect(Setup::BackupManager).to receive(:from_config).with(io: CONCRETE_IO, config_path: nil).and_return backup_manager
      expect(backup_manager).to receive(:load_backups!)
      expect(get_backup_manager).to eq(backup_manager)
    end

    it 'creates backup manager with passed in options' do
      expect(Setup::BackupManager).to receive(:from_config).with(io: DRY_IO, config_path: '/config/path').and_return backup_manager
      expect(backup_manager).to receive(:load_backups!)
      expect(get_backup_manager({ dry: true, config: '/config/path' })).to eq(backup_manager)
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
  
  def get_backup_manager(options = {})
    actual_manager = nil
    setup_cli.with_backup_manager(options) { |backup_manager| actual_manager = backup_manager }
    actual_manager
  end

  describe '#with_backup_manager' do
    context 'when default options are given' do
      it 'creates a default backup manager' do
        expect(Setup::BackupManager).to receive(:from_config).with(io: CONCRETE_IO, config_path: nil).and_return backup_manager
        expect(backup_manager).to receive(:load_backups!)
        expect(get_backup_manager).to eq(backup_manager)
      end
    end

    context 'when --dry and --config=/config/path' do
      it 'creates backup manager with passed in options' do
        expect(Setup::BackupManager).to receive(:from_config).with(io: DRY_IO, config_path: '/config/path').and_return backup_manager
        expect(backup_manager).to receive(:load_backups!)
        expect(get_backup_manager({ dry: true, config: '/config/path' })).to eq(backup_manager)
      end
    end
  end
end

# Integration tests.
RSpec.describe './setup' do
  let(:setup)  { Cli::SetupCLI }
  let(:cmd)    { instance_double(HighLine) }

  # Asserts that a file exists with the specified content.
  def assert_file_content(path, content)
    expect(File.exist? path).to be true
    expect(File.read path).to eq(content)
  end

  # Asserts that a yaml file exists with the specified dictionary.
  def assert_yaml_content(path, yaml_hash)
    expect(File.exist? path).to be true
    expect(YAML::load File.read(path)).to eq(yaml_hash)
  end

  # Saves a file with the specified content.
  def save_file_content(path, content)
    FileUtils.mkdir_p File.dirname path
    File.write path, content
  end

  # Saves a yaml dictionary under path.
  def save_yaml_content(path, yaml_hash)
    save_file_content path, YAML::dump(yaml_hash)
  end
  
  # Creates a symlink between files.
  def link_files(path, link_path)
    File.link path, link_path
  end
  
  # Creates a yaml file that should fail to parse.
  def corrupt_yaml_file(path)
    save_file_content path, "---\n"
  end

  # Asserts that the two files have the same content.
  def assert_copies(backup_path: nil, restore_path: nil)
    expect(File.exist? backup_path).to be true
    expect(File.exist? restore_path).to be true
    expect(File.identical? backup_path, restore_path).to be false
    expect(IO.read backup_path).to eq(IO.read restore_path)
  end

  # Asserts that the two files are symlinks.
  def assert_symlinks(backup_path: nil, restore_path: nil, content: nil)
    expect(File.exist? backup_path).to be true
    expect(File.exist? restore_path).to be true
    expect(File.identical? backup_path, restore_path).to be true
    assert_file_content backup_path, content unless content.nil?
  end
  
  def get_backup_path(path)
    File.join @dotfiles_dir, path
  end
  
  def get_restore_path(path)
    File.join @tmpdir, 'machine', path
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

    @dotfiles_dir = File.join(@tmpdir, 'dotfiles/dotfiles1')
    @dotfiles_config = File.join(@dotfiles_dir, 'config.yml')

    stub_const 'Setup::Backup::APPLICATIONS_DIR', @applications_dir
    stub_const 'Setup::BackupManager::DEFAULT_CONFIG_PATH', @default_config_root
    stub_const 'Setup::BackupManager::DEFAULT_RESTORE_ROOT', @default_restore_root
    stub_const 'Setup::Backup::DEFAULT_BACKUP_ROOT', @default_backup_root
    stub_const 'Setup::Backup::DEFAULT_BACKUP_DIR', @default_backup_dir

    # Take over the interactions with console in order to stub out user interaction.
    stub_const 'Setup::Cli::Commandline', cmd

    # Create a basic layout of files on the disk.
    FileUtils.mkdir_p File.join(@tmpdir, 'apps')
    FileUtils.mkdir_p File.join(@tmpdir, 'machine')

    # An app with no files to sync.
    save_yaml_content File.join(@tmpdir, 'apps/app.yml'), 'name' => 'app', 'files' => []

    # An app where the file is only present at the restore location.
    save_yaml_content File.join(@tmpdir, 'apps/vim.yml'), 'name' => 'vim', 'files' => ['.vimrc']
    save_file_content get_restore_path('.vimrc'), '; Vim configuration.'
    
    # An app where the backup will overwrite files.
    save_yaml_content File.join(@tmpdir, 'apps/code.yml'), 'name' => 'code', 'files' => ['.vscode']
    save_file_content get_backup_path('code/_vscode'), 'some content'
    save_file_content get_restore_path('.vscode'), 'different content' 
    
    # An app where only some files exist on the machine.
    # An app which only contains the file in the backup directory.    
    save_yaml_content File.join(@tmpdir, 'apps/bash.yml'), 'name' => 'bash', 'files' => ['.bashrc', '.bash_local']
    save_file_content get_backup_path('bash/_bashrc'), 'bashrc file'
    
    # An app where no files exist.
    save_yaml_content File.join(@tmpdir, 'apps/git.yml'), 'name' => 'git', 'files' => ['.gitignore', '.gitconfig']
    
    # An app where the both backup and restore have the same content.
    save_yaml_content File.join(@tmpdir, 'apps/python.yml'), 'name' => 'python', 'files' => ['.pythonrc']
    save_file_content get_backup_path('python/_pythonrc'), 'pythonrc'
    save_file_content get_restore_path('.pythonrc'), 'pythonrc'
  end

  describe '--help' do
    it { capture(:stdout) { setup.start %w[--help] } }
  end

  describe 'init' do

    it 'should clone repositories'

    context 'when no options are passed in' do
      it 'should prompt by default' do
        expect(cmd).to receive(:agree).once.and_return true
        setup.start %w[init]

        assert_yaml_content @default_config_root, 'backups' => [@default_backup_dir]
        assert_yaml_content @default_backup_config, 'enabled_task_names' => ['code', 'python', 'vim'], 'disabled_task_names' => []
      end
    end

    context 'when --enable_new=prompt' do
      it 'should create a local backup and enable tasks if user replies y to prompt' do
        expect(cmd).to receive(:agree).once.and_return true
        setup.start %w[init --enable_new=prompt]

        assert_yaml_content @default_config_root,'backups' => [@default_backup_dir]
        assert_yaml_content @default_backup_config,'enabled_task_names' => ['code', 'python', 'vim'], 'disabled_task_names' => []
      end

      it 'should create a local backup and disable tasks if user replies n to prompt' do
        expect(cmd).to receive(:agree).once.and_return false
        setup.start %w[init --enable_new=prompt]

        assert_yaml_content @default_config_root,'backups' => [@default_backup_dir]
        assert_yaml_content @default_backup_config,'enabled_task_names' => [], 'disabled_task_names' => ['code', 'python', 'vim']
      end
    end

    context 'when --enable_new=all' do
      it 'should create a local backup and enable found tasks' do
        save_yaml_content @default_config_root, 'backups' => [@dotfiles_dir]
        setup.start %w[init --enable_new=all]

        assert_yaml_content @default_config_root, 'backups' => [@dotfiles_dir, @default_backup_dir]
        assert_yaml_content @default_backup_config, 'enabled_task_names' => ['code', 'python', 'vim', 'bash'], 'disabled_task_names' => []
        assert_yaml_content @dotfiles_config, 'enabled_task_names' => ['bash', 'code', 'python', 'vim'], 'disabled_task_names' => []
      end
    end

    context 'when --enable_new=none' do
      it 'should create a local backup and disable found tasks' do
        setup.start %w[init --enable_new=none]

        assert_yaml_content @default_config_root,'backups' => [@default_backup_dir]
        assert_yaml_content @default_backup_config,'enabled_task_names' => [], 'disabled_task_names' => ['code', 'python', 'vim']
      end
    end

    context 'when --dir=./custom/path' do
      it 'should not affect default path'
      it 'should not affect relative path'
      it 'should not affect absolute path'
      it 'should create a backup relative to the new dir'
    end
  end
  
  def assert_files_unchanged
    expect(File.exist? get_backup_path('vim/_vimrc')).to be false
    assert_file_content get_backup_path('code/_vscode'), 'some content'
    assert_file_content get_restore_path('.vscode'), 'different content'
    expect(File.exist? get_restore_path('.bashrc')).to be false
    expect(File.identical? get_restore_path('.pythonrc'), get_backup_path('python/_pythonrc')).to be false
  end

  describe 'backup' do
    before(:each) { save_yaml_content @default_config_root, 'backups' => [@dotfiles_dir] }

    it 'should backup' do
      app_result = setup.start %w[backup --enable_new=all]

      expect(app_result).to be true
      assert_symlinks restore_path: get_restore_path('.vimrc'), backup_path: get_backup_path('vim/_vimrc')
      assert_symlinks restore_path: get_restore_path('.vscode'), backup_path: get_backup_path('code/_vscode'), content: 'different content'
      expect(File.exist? get_restore_path('.bashrc')).to be false
      assert_symlinks restore_path: get_restore_path('.pythonrc'), backup_path: get_backup_path('python/_pythonrc')
    end

    it 'should not backup if the task is disabled' do
      app_result = setup.start %w[backup --enable_new=none]

      expect(app_result).to be true
      assert_files_unchanged
    end

    context 'when --copy=true' do
      it 'should generate file copies instead of symlinks'
    end
  end

  describe 'restore' do
    before(:each) { save_yaml_content @default_config_root, 'backups' => [@dotfiles_dir] }
  
    it 'should restore' do
      app_result = setup.start %w[restore --enable_new=all]

      expect(app_result).to be true
      expect(File.exist? get_backup_path('vim/_vimrc')).to be false
      assert_symlinks restore_path: get_restore_path('.vscode'), backup_path: get_backup_path('code/_vscode'), content: 'some content'
      assert_symlinks restore_path: get_restore_path('.bashrc'), backup_path: get_backup_path('bash/_bashrc'), content: 'bashrc file'
      assert_symlinks restore_path: get_restore_path('.pythonrc'), backup_path: get_backup_path('python/_pythonrc'), content: 'pythonrc'
    end

    it 'should not restore if the task is disabled' do
      app_result = setup.start %w[restore --enable_new=none]

      expect(app_result).to be true
      assert_files_unchanged
    end

    context 'when --copy=true' do
      it 'should generate file copies instead of symlinks'
    end
  end

  describe 'cleanup' do
    let(:cleanup_files) { ['bash/setup-backup-1-_bash_local', 'vim/setup-backup-1-_vimrc'].map(&method(:get_backup_path)) }
    before(:each) do 
      save_yaml_content @default_config_root, 'backups' => [@dotfiles_dir]
      save_yaml_content @dotfiles_config, 'enabled_task_names' => ['bash', 'vim']
      cleanup_files.each { |path| save_file_content path, path }
    end
  
    it 'should cleanup old backups' do
      expect(cmd).to receive(:agree).and_return true
      app_result = setup.start %w[cleanup]
      
      expect(app_result).to be true
      cleanup_files.each { |path| expect(File.exist? path).to be false }
    end

    context 'when no options are passed in' do
      it 'should require confirmation' do
        expect(cmd).to receive(:agree).and_return false
        app_result = setup.start %w[cleanup]
        
        expect(app_result).to be true
        cleanup_files.each { |path| expect(File.exist? path).to be true }
      end
    end

    context 'when --confirm=false' do
      it 'should cleanup old backups' do
        app_result = setup.start %w[cleanup --confirm=false]
        
        expect(app_result).to be true
        cleanup_files.each { |path| expect(File.exist? path).to be false }
      end
    end
  end

  describe 'status' do
    it 'should print status' do
      save_yaml_content @default_config_root, 'backups' => [@dotfiles_dir]
      save_yaml_content @dotfiles_config, 'enabled_task_names' => ['bash', 'code', 'vim', 'python'], 'disabled_task_names' => []
      result = capture_stdio { setup.start %w[status] }
      expected_output = 'write expected output here'
      
      expect(result[:result]).to be true
      expect(result[:stderr]).to eq('')
      expect(result[:stdout]).to eq(expected_output)
    end
  end

  describe 'app' do
    before(:each) do
      save_yaml_content @default_config_root, 'backups' => [@dotfiles_dir]
      save_yaml_content @dotfiles_config, 'enabled_task_names' => ['bash', 'code'], 'disabled_task_names' => ['vim']
    end
  
    describe 'add' do
      it 'should add apps' do
        setup.start %w[app add code vim]
        assert_yaml_content @dotfiles_config, 'enabled_task_names' => ['bash', 'code', 'vim'], 'disabled_task_names' => []
      end
    end

    describe 'remove' do
      it 'should remove apps' do
        setup.start %w[app remove code vim]
        assert_yaml_content @dotfiles_config, 'enabled_task_names' => ['bash'], 'disabled_task_names' => ['vim', 'code']
      end
    end

    describe 'list' do
      it 'should list apps ready to be add/remove' do
        result = capture_stdio { setup.start %w[app list] }
        expected_output =
          "Enabled apps:\n" \
          "bash, code\n\n" \
          "Disabled apps:\n" \
          "vim\n\n" \
          "New apps:\n" \
          "python\n"
        
        expect(result[:result]).to be true
        expect(result[:stderr]).to eq('')
        expect(result[:stdout]).to eq(expected_output)
      end
    end
  end
  
  # Check that calling a command with no parameters will make it return false.
  def assert_commands_fail
    commands = ['init', 'restore', 'backup', 'cleanup', 'status', 'app add', 'app remove', 'app list']
    commands.each do |command|
      app_result = setup.start command.split(' ')
      expect(app_result).to be false
    end
  end

  context 'when a global config file is invalid' do
    it 'should fail commands' do
      corrupt_yaml_file @default_config_root
      assert_commands_fail
    end
  end

  context 'when a backup config file is invalid' do
    it 'should fail commands' do
      save_yaml_content @default_config_root, 'backups' => [@dotfiles_dir]
      corrupt_yaml_file @dotfiles_config
      assert_commands_fail
    end
  end

  context 'when a task config file is invalid' do
    it 'should fail commands' do
      save_yaml_content @default_config_root, 'backups' => [@dotfiles_dir]
      corrupt_yaml_file File.join(@tmpdir, 'apps/vim.yml')
      assert_commands_fail
    end
  end
end

end # module Setup
