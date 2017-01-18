# This tests the overall appliction integration test.
require 'setup/applications'
require 'setup/backups'
require 'setup/cli'
require 'setup/package'
require 'setup/package_template'
require 'setup/test_applications'
require 'setup/io'

require 'tmpdir'

module Setup

$thor_runner = false
$0 = "setup"
ARGV.clear

RSpec.shared_examples 'CLIHelper' do |cli_cls|
  let(:cli) { cli_cls.new }
  let(:backup_manager) { instance_double(Setup::BackupManager) }

  def get_backup_manager(options = {})
    expect(backup_manager).to receive(:load_backups!)
    cli.init_backup_manager
    cli.backup_manager
  end

  describe '#init_backup_manager' do
    it 'creates backup manager with default parameters when no options given' do
      expect(Setup::BackupManager).to receive(:from_config).with(an_instance_of(SyncContext)).and_return backup_manager
      expect(get_backup_manager).to eq(backup_manager)
    end

    it 'creates backup manager with passed in options' do
      expect(Setup::BackupManager).to receive(:from_config).with(an_instance_of(SyncContext)).and_return backup_manager
      expect(get_backup_manager({ dry: true })).to eq(backup_manager)
    end
  end
end

RSpec.describe Cli::Package do
  include_examples 'CLIHelper', Cli::Package
end

RSpec.describe Cli::Program do
  include_examples 'CLIHelper', Cli::Program
end

# Integration tests.
RSpec.describe './setup' do
  let(:cmd)    { instance_double(HighLine) }
  let(:ctx)    { SyncContext.new backup_dir: @dotfiles_dir, restore_dir: File.join(@tmpdir, 'machine') }

  def setup(args, config={})
    Cli::Program.start args, config
  end

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

  def assert_applications_content(path, applications)
    assert_file_content path, Setup::Templates::applications(applications)
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

  def save_applications_content(path, applications)
    save_file_content path, Setup::Templates::applications(applications)
  end

  # Creates a symlink between files.
  def link_files(path, link_path)
    File.link path, link_path
  end

  # Asserts that the two files have the same content.
  def assert_copies(file1, file2, content: nil)
    expect(File.identical? file1, file2).to be false
    expect(File.read file1).to eq(File.read file2)
    expect(File.read file1).to eq(content) unless content.nil?
  end

  # Asserts that the two files are symlinks.
  def assert_symlinks(file1, file2, content: nil)
    expect(File.identical? file1, file2).to be true
    assert_file_content file1, content unless content.nil?
  end

  def assert_ran_unsuccessfully(result)
    @output_lines = @log_output.readlines

    expect(result).to be false
  end

  def assert_ran_without_errors(result)
    @output_lines = @log_output.readlines

    expect(result).to_not be false
    expect(@output_lines).to_not include(start_with 'E:')
  end

  def assert_ran_with_errors(result)
    @output_lines = @log_output.readlines

    expect(result).to_not be false
    expect(@output_lines).to include(start_with 'E:')
  end

  def get_overwrite_choice
    menu = instance_double('menu')
    expect(cmd).to receive(:choose).and_yield menu
    expect(menu).to receive(:prompt=).with('Keep back up, restore, back up for all, restore for all?')
    allow(menu).to receive(:choice).with(:b)
    allow(menu).to receive(:choice).with(:r)
    allow(menu).to receive(:choice).with(:ba)
    allow(menu).to receive(:choice).with(:ra)
      menu
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
    @default_config_root   = File.join(@tmpdir, 'setup.yml')
    @default_restore_dir  = File.join(@tmpdir, 'machine')
    @default_backup_root   = File.join(@tmpdir, 'dotfiles')
    @default_backup_dir    = File.join(@default_backup_root, 'local')
    @default_applications_dir = File.join(@default_backup_dir, '_packages/applications.rb')

    @dotfiles_dir = File.join(@default_backup_root, 'dotfiles1')
    @apps_dir      = File.join(@dotfiles_dir, '_packages')
    @applications_path = File.join(@apps_dir, 'applications.rb')

    # Remove data that can be modified by previous test run.
    FileUtils.rm_rf @apps_dir
    FileUtils.rm_rf ctx.restore_path
    FileUtils.rm_rf ctx.backup_path
    FileUtils.rm_rf @default_backup_root

    stub_const 'Setup::APPLICATIONS', [
      Test::AppPackage,
      Test::BashPackage,
      Test::CodePackage,
      Test::GitPackage,
      Test::PythonPackage,
      Test::RubocopPackage,
      Test::VimPackage
    ]
    stub_const 'Setup::BackupManager::DEFAULT_CONFIG_PATH', @default_config_root
    stub_const 'Setup::Package::DEFAULT_RESTORE_DIR', @default_restore_dir
    stub_const 'Setup::Backup::DEFAULT_BACKUP_ROOT', @default_backup_root
    stub_const 'Setup::Backup::DEFAULT_BACKUP_DIR', @default_backup_dir

    # Take over the interactions with console in order to stub out user interaction.
    allow(HighLine).to receive(:new).and_return cmd
    ENV['editor'] = 'vim'

    # Create a basic layout of files on the disk.
    FileUtils.mkdir_p File.join(@apps_dir)
    FileUtils.mkdir_p File.join(@tmpdir, 'machine')

    save_yaml_content @default_config_root, 'backups' => [@dotfiles_dir]

    save_file_content ctx.restore_path('.test_vimrc'), '; Vim configuration.'
    save_file_content ctx.backup_path('code/_test_vscode'), 'some content'
    save_file_content ctx.restore_path('.test_vscode'), 'different content'
    save_file_content ctx.backup_path('bash/_test_bashrc'), 'bashrc file'
    save_file_content ctx.backup_path('python/_test_pythonrc'), 'pythonrc'
    save_file_content ctx.restore_path('.test_pythonrc'), 'pythonrc'
    save_file_content ctx.backup_path('rubocop/_test_rubocop'), 'rubocop'
    link_files ctx.backup_path('rubocop/_test_rubocop'), ctx.restore_path('.test_rubocop')
  end

  describe '--help' do
    it do
      expect { setup %w[--help] }.to output(
"Commands:
  setup cleanup                       # Cleans up previous backups
  setup discover                      # Discovers applications
  setup help [COMMAND]                # Describe available commands or one specific command
  setup init [<backups>...]           # Initializes backups
  setup package <subcommand> ...ARGS  # Add/remove packages to be backed up
  setup status                        # Returns the sync status
  setup sync                          # Synchronize your settings

Options:
  [--help], [--no-help]        # Print help for a specific command
  [--verbose], [--no-verbose]  # Print verbose information to stdout

").to_stdout
    end
  end

  describe 'init' do
    # The default test setup includes a default_config_root. Remove it to init from a bare repository.
    before(:each) { File.delete @default_config_root }

    context 'when --dir=./custom/path' do
      let(:custom_path) { File.join(@tmpdir, 'custom') }

      it 'should not affect default path' do
        assert_ran_without_errors setup ['init', "--dir=#{custom_path}", '--enable_new=all']

        assert_yaml_content @default_config_root, 'backups' => [@default_backup_dir]
      end

      it 'should not affect absolute path' do
        absolute_path = File.join(@tmpdir, 'absolute')
        assert_ran_without_errors setup ['init', "--dir=#{custom_path}", '--enable_new=all', absolute_path]

        assert_yaml_content @default_config_root, 'backups' => [absolute_path]
      end

      it 'should create a backup relative to the new dir' do
        assert_ran_without_errors setup ['init', '--enable_new=all', "--dir=#{custom_path}", "repo;"]

        assert_yaml_content @default_config_root, 'backups' => [File.join(custom_path, 'repo')]
      end
    end
  end

  describe 'discover' do
    context 'when no options are passed in' do
      it 'should prompt by default' do
        expect(cmd).to receive(:agree).once.and_return true
        assert_ran_without_errors setup %w[discover]

        assert_yaml_content @default_config_root, 'backups' => [@dotfiles_dir]
        assert_applications_content @applications_path, [Test::BashPackage, Test::CodePackage, Test::PythonPackage, Test::RubocopPackage, Test::VimPackage]
      end
    end

    context 'when --enable_new=all' do
      it 'should create a local backup and enable found tasks' do
        assert_ran_without_errors setup %w[discover --enable_new=all]

        assert_yaml_content @default_config_root, 'backups' => [@dotfiles_dir]
        assert_applications_content @applications_path, [Test::BashPackage, Test::CodePackage, Test::PythonPackage, Test::RubocopPackage, Test::VimPackage]
      end
    end

    context 'when --enable_new=prompt' do
      it 'should create a local backup and enable tasks if user replies y to prompt' do
        expect(cmd).to receive(:agree).once.and_return true
        assert_ran_without_errors setup %w[discover --enable_new=prompt]

        assert_yaml_content @default_config_root,'backups' => [@dotfiles_dir]
        assert_applications_content @applications_path, [Test::BashPackage, Test::CodePackage, Test::PythonPackage, Test::RubocopPackage, Test::VimPackage]
      end

      it 'should create a local backup and disable tasks if user replies n to prompt' do
        expect(cmd).to receive(:agree).once.and_return false
        assert_ran_without_errors setup %w[discover --enable_new=prompt]

        assert_yaml_content @default_config_root,'backups' => [@dotfiles_dir]
        expect(File.exist? @applications_path).to be false
      end
    end

    context 'when --enable_new=none' do
      it 'should create a local backup and disable found tasks' do
        assert_ran_without_errors setup %w[discover --enable_new=none]

        assert_yaml_content @default_config_root,'backups' => [@dotfiles_dir]
        expect(File.exist? @default_applications_dir).to be false
      end
    end

    # TODO(drognanar): Move discovery tests here.
  end

  describe 'sync' do
    it 'should sync with restore overwrite' do
      save_applications_content @applications_path, [Test::BashPackage, Test::CodePackage, Test::PythonPackage, Test::RubocopPackage, Test::VimPackage]

      expect(get_overwrite_choice).to receive(:choice).with(:r).and_yield
      assert_ran_with_errors setup %w[sync --enable_new=none --verbose], package: lambda { |ctx| ctx.backup @dotfiles_dir }

      expect(@output_lines.join).to eq(
"Syncing:
I: Syncing package bash:
I: Syncing .test_bashrc
V: Symlinking \"#{ctx.backup_path('bash/_test_bashrc')}\" with \"#{ctx.restore_path('.test_bashrc')}\"
I: Syncing .test_bash_local
E: Cannot sync. Missing both backup and restore.
I: Syncing package code:
I: Syncing .test_vscode
W: Needs to overwrite a file
W: Backup: \"#{ctx.backup_path('code/_test_vscode')}\"
W: Restore: \"#{ctx.restore_path('.test_vscode')}\"
V: Saving a copy of file \"#{ctx.backup_path('code/_test_vscode')}\" under \"#{ctx.backup_path('code')}\"
V: Moving file from \"#{ctx.restore_path('.test_vscode')}\" to \"#{ctx.backup_path('code/_test_vscode')}\"
V: Symlinking \"#{ctx.backup_path('code/_test_vscode')}\" with \"#{ctx.restore_path('.test_vscode')}\"
I: Syncing package python:
I: Syncing .test_pythonrc
V: Symlinking \"#{ctx.backup_path('python/_test_pythonrc')}\" with \"#{ctx.restore_path('.test_pythonrc')}\"
I: Syncing package rubocop:
I: Syncing .test_rubocop
I: Syncing package vim:
I: Syncing .test_vimrc
V: Moving file from \"#{ctx.restore_path('.test_vimrc')}\" to \"#{ctx.backup_path('vim/_test_vimrc')}\"
V: Symlinking \"#{ctx.backup_path('vim/_test_vimrc')}\" with \"#{ctx.restore_path('.test_vimrc')}\"
")

      assert_symlinks ctx.restore_path('.test_vimrc'), ctx.backup_path('vim/_test_vimrc')
      assert_symlinks ctx.restore_path('.test_vscode'), ctx.backup_path('code/_test_vscode'), content: 'different content'
      assert_symlinks ctx.restore_path('.test_bashrc'), ctx.backup_path('bash/_test_bashrc'), content: 'bashrc file'
      assert_symlinks ctx.restore_path('.test_pythonrc'), ctx.backup_path('python/_test_pythonrc')
    end

    it 'should sync with backup overwrite' do
      save_applications_content @applications_path, [Test::BashPackage, Test::CodePackage, Test::PythonPackage, Test::RubocopPackage, Test::VimPackage]

      expect(get_overwrite_choice).to receive(:choice).with(:b).and_yield
      assert_ran_with_errors setup %w[sync --enable_new=none --verbose], package: lambda { |ctx| ctx.backup @dotfiles_dir }

      expect(@output_lines.join).to eq(
"Syncing:
I: Syncing package bash:
I: Syncing .test_bashrc
V: Symlinking \"#{ctx.backup_path('bash/_test_bashrc')}\" with \"#{ctx.restore_path('.test_bashrc')}\"
I: Syncing .test_bash_local
E: Cannot sync. Missing both backup and restore.
I: Syncing package code:
I: Syncing .test_vscode
W: Needs to overwrite a file
W: Backup: \"#{ctx.backup_path('code/_test_vscode')}\"
W: Restore: \"#{ctx.restore_path('.test_vscode')}\"
V: Saving a copy of file \"#{ctx.restore_path('.test_vscode')}\" under \"#{ctx.backup_path('code')}\"
V: Symlinking \"#{ctx.backup_path('code/_test_vscode')}\" with \"#{ctx.restore_path('.test_vscode')}\"
I: Syncing package python:
I: Syncing .test_pythonrc
V: Symlinking \"#{ctx.backup_path('python/_test_pythonrc')}\" with \"#{ctx.restore_path('.test_pythonrc')}\"
I: Syncing package rubocop:
I: Syncing .test_rubocop
I: Syncing package vim:
I: Syncing .test_vimrc
V: Moving file from \"#{ctx.restore_path('.test_vimrc')}\" to \"#{ctx.backup_path('vim/_test_vimrc')}\"
V: Symlinking \"#{ctx.backup_path('vim/_test_vimrc')}\" with \"#{ctx.restore_path('.test_vimrc')}\"
")

      assert_symlinks ctx.restore_path('.test_vimrc'), ctx.backup_path('vim/_test_vimrc')
      assert_symlinks ctx.restore_path('.test_vscode'), ctx.backup_path('code/_test_vscode'), content: 'some content'
      assert_symlinks ctx.restore_path('.test_bashrc'), ctx.backup_path('bash/_test_bashrc'), content: 'bashrc file'
      assert_symlinks ctx.restore_path('.test_pythonrc'), ctx.backup_path('python/_test_pythonrc')
    end

    it 'should not sync if the task is disabled' do
      save_applications_content @applications_path, []
      assert_ran_without_errors setup %w[sync --enable_new=none], package: lambda { |ctx| ctx.backup @dotfiles_dir }

      expect(File.exist? ctx.backup_path('vim/_test_vimrc')).to be false
      assert_file_content ctx.backup_path('code/_test_vscode'), 'some content'
      assert_file_content ctx.restore_path('.test_vscode'), 'different content'
      expect(File.exist? ctx.restore_path('.test_bashrc')).to be false
      expect(File.identical? ctx.restore_path('.test_pythonrc'), ctx.backup_path('python/_test_pythonrc')).to be false
    end

    context 'when --copy' do
      it 'should generate file copies instead of symlinks' do
        save_applications_content @applications_path, [Test::BashPackage, Test::CodePackage, Test::PythonPackage, Test::RubocopPackage, Test::VimPackage]

        expect(get_overwrite_choice).to receive(:choice).with(:r).and_yield
        assert_ran_with_errors setup %w[sync --enable_new=none --copy], package: lambda { |ctx| ctx.backup @dotfiles_dir }

        assert_copies ctx.restore_path('.test_vimrc'), ctx.backup_path('vim/_test_vimrc')
        assert_copies ctx.restore_path('.test_vscode'), ctx.backup_path('code/_test_vscode'), content: 'different content'
        assert_copies ctx.restore_path('.test_bashrc'), ctx.backup_path('bash/_test_bashrc'), content: 'bashrc file'
        assert_copies ctx.restore_path('.test_pythonrc'), ctx.backup_path('python/_test_pythonrc')
      end
    end
  end

  describe 'cleanup' do
    let(:cleanup_files) { ['bash/setup-backup-1-_test_bash_local', 'vim/setup-backup-1-_test_vimrc'].map(&ctx.method(:backup_path)) }
    before(:each) do
      save_applications_content @applications_path, [Test::BashPackage, Test::VimPackage]
    end

    def create_cleanup_files
      cleanup_files.each { |path| save_file_content path, path }
      FileUtils.mkdir_p ctx.backup_path('bash/folder/nested/deeper')
    end

    it 'should report when there is nothing to clean' do
      assert_ran_without_errors setup %w[cleanup], package: lambda { |ctx| ctx.backup @dotfiles_dir }

      expect(@output_lines.join).to eq(
"Nothing to clean.
")
    end

    it 'should cleanup old backups' do
      create_cleanup_files
      expect(cmd).to receive(:agree).twice.and_return true
      assert_ran_without_errors setup %w[cleanup], package: lambda { |ctx| ctx.backup @dotfiles_dir }

      cleanup_files.each { |path| expect(File.exist? path).to be false }
      expect(@output_lines.join).to eq(
"Deleting \"#{ctx.backup_path('bash/setup-backup-1-_test_bash_local')}\"
Deleting \"#{ctx.backup_path('vim/setup-backup-1-_test_vimrc')}\"
")
    end

    context 'when no options are passed in' do
      it 'should require confirmation' do
        create_cleanup_files
        expect(cmd).to receive(:agree).twice.and_return false
        assert_ran_without_errors setup %w[cleanup], package: lambda { |ctx| ctx.backup @dotfiles_dir }

        cleanup_files.each { |path| expect(File.exist? path).to be true }
      end
    end

    context 'when --confirm=false' do
      it 'should cleanup old backups' do
        create_cleanup_files
        assert_ran_without_errors setup %w[cleanup --confirm=false], package: lambda { |ctx| ctx.backup @dotfiles_dir }

        cleanup_files.each { |path| expect(File.exist? path).to be false }
      end
    end
  end

  describe 'status' do
    it 'should print an empty message if no packages exist' do
      assert_ran_without_errors setup %w[status], package: lambda { |ctx| Package.new ctx }

      expect(@output_lines.join).to eq(
"Current status:

W: No packages enabled.
W: Use ./setup package add to enable packages.
")
    end

    it 'should print status' do
      save_applications_content @applications_path, [Test::BashPackage, Test::CodePackage, Test::VimPackage, Test::PythonPackage, Test::RubocopPackage]
      assert_ran_without_errors setup %w[status], dir: @dotfiles_dir, package: lambda { |ctx| ctx.package_from_files '_packages/*.rb' }

      expect(@output_lines.join).to eq(
"Current status:

bash:
    .test_bashrc: needs sync
    .test_bash_local: error: Cannot sync. Missing both backup and restore.
code:
    .test_vscode: differs
python:
    .test_pythonrc: needs sync
rubocop:
    .test_rubocop: up to date
vim:
    .test_vimrc: needs sync
")
    end

    it 'should print verbose status' do
      save_applications_content @applications_path, [Test::BashPackage, Test::CodePackage, Test::VimPackage, Test::PythonPackage, Test::RubocopPackage]
      assert_ran_without_errors setup %w[status --verbose], dir: @dotfiles_dir, package: lambda { |ctx| ctx.package_from_files '_packages/*.rb' }

      expect(@output_lines.join).to eq(
"Current status:

bash:
    .test_bashrc: needs sync
    .test_bash_local: error: Cannot sync. Missing both backup and restore.
code:
    .test_vscode: differs
python:
    .test_pythonrc: needs sync
rubocop:
    .test_rubocop: up to date
vim:
    .test_vimrc: needs sync
")
    end
  end

  describe 'package' do
    describe 'add' do
      it 'should add packages' do
        save_applications_content @applications_path, [Test::BashPackage, Test::CodePackage]
        assert_ran_without_errors setup %w[package add code vim]
        assert_applications_content @applications_path, [Test::BashPackage, Test::CodePackage, Test::VimPackage]
      end
    end

    describe 'remove' do
      it 'should remove packages' do
        save_applications_content @applications_path, [Test::BashPackage, Test::CodePackage]
        assert_ran_without_errors setup %w[package remove code vim]
        assert_applications_content @applications_path, [Test::BashPackage]
      end
    end

    describe 'list' do
      it 'should list packages ready to be add/remove' do
        save_applications_content @applications_path, [Test::BashPackage, Test::CodePackage]
        assert_ran_without_errors setup %w[package list]

        expect(@output_lines.join).to eq(
"Enabled packages:
bash, code

New packages:
python, rubocop, vim
")
      end
    end

    describe 'edit' do
      it 'should allow to edit a package' do
        expect(CONCRETE_IO).to receive(:system).with("vim #{File.join(@apps_dir, 'vim.rb')}")
        assert_ran_without_errors setup %w[package edit vim --global]
      end

      it 'should create a new package from template' do
        package_path = File.join(@apps_dir, 'unknown.rb')
        expect(CONCRETE_IO).to receive(:system).with("vim #{package_path}").ordered
        assert_ran_without_errors setup %w[package edit unknown --global]

        assert_file_content package_path,
"class UnknownPackage < Setup::Package
  package_name 'Unknown'

  def steps
  end
end
"
      end
    end
  end

  # Check that corrupting a file will make all commands fail.
  def assert_commands_fail_if_corrupt(corrupt_file_path)
    save_file_content corrupt_file_path, "---\n"

    commands = ['init', 'sync', 'cleanup', 'status', 'package add', 'package remove', 'package list', 'package edit foo']
    commands.each do |command|
      assert_ran_unsuccessfully setup command.split(' ')
      expect(@output_lines).to match_array([start_with("E: Could not load \"#{corrupt_file_path}\": ")])
    end
  end

  context 'when a global config file is invalid' do
    it 'should fail commands' do
      assert_commands_fail_if_corrupt @default_config_root
    end
  end

  context 'when a package is invalid' do
    it 'should fail commands' do
      save_yaml_content @default_config_root, 'backups' => [@dotfiles_dir]
      assert_commands_fail_if_corrupt File.join(@apps_dir, 'vim.rb')
    end
  end
end

end # module Setup
