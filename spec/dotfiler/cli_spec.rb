# This tests the overall appliction integration test.
require 'dotfiler/applications'
require 'dotfiler/sync_utils'
require 'dotfiler/cli'
require 'dotfiler/extend/string_utils'
require 'dotfiler/io'
require 'dotfiler/tasks/package'
require 'dotfiler/templates'
require 'dotfiler/test_applications'

require 'tmpdir'

SAMPLE_BACKUP = <<-CODE.strip_heredoc
  require 'dotfiler'

  class MyBackup < Dotfiler::Tasks::Package
    package_name ''

    def steps
      yield package_from_files '_packages/*.rb'
    end
  end
CODE

RSpec.shared_examples 'CLIHelper' do |cli_cls|
  let(:cli_cls) { cli_cls }
  let(:ctx) { instance_double(SyncContext) }
  let(:package) { instance_double(Package) }
  let(:backup_manager) { instance_double(Dotfiler::BackupManager) }

  def create_backup_manager(options = {})
    expect(SyncContext).to receive(:new).with(a_hash_including(options)).and_return ctx
    expect(ctx).to receive(:with_backup_dir).and_return ctx
    expect(ctx).to receive(:add_default_applications).and_return ctx
    expect(ctx).to receive(:backup_path).with('backups.rb').and_return 'path/backups.rb'
    expect(ctx).to receive(:package_from_files).with('path/backups.rb').and_return package
    cli_cls.new([], options).create_backup_manager
  end

  describe '#create_backup_manager' do
    it 'creates backup manager with default parameters when no options given' do
      expect(create_backup_manager).to eq(package)
    end

    it 'creates backup manager with passed in options' do
      expect(create_backup_manager(dry: true)).to eq(package)
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
RSpec.describe './dotfiler' do
  let(:cmd)    { instance_double(HighLine) }
  let(:ctx)    { SyncContext.new backup_dir: @dotfiles_dir, restore_dir: @default_restore_dir }

  # Run the dotfiler program
  def dotfiler(args, config = {})
    config[:on_error] ||= ->(e) { @exit_reason = e }
    Cli::Program.start args, config
    @output_lines = @log_output.readlines
    @exit_reason
  end

  # Asserts that a file exists with the specified content.
  def assert_file_content(path, content)
    expect(File.exist?(path)).to be true
    expect(File.read(path)).to eq(content)
  end

  def assert_package_content(path, name, files)
    assert_file_content path, Dotfiler::Templates.package(name, files: files)
  end

  # Saves a file with the specified content.
  def save_file_content(path, content)
    FileUtils.mkdir_p File.dirname path
    File.write path, content
  end

  def save_backups_content(path)
    save_file_content path, Dotfiler::Templates.backups
  end

  def save_package_content(path, name, files: [], packages: [])
    save_file_content path, Dotfiler::Templates.package(name, files: files, packages: packages)
  end

  # Creates a symlink between files.
  def link_files(path, link_path)
    File.link path, link_path
  end

  # Asserts that the two files have the same content.
  def assert_copies(file1, file2, content: nil)
    expect(File.identical?(file1, file2)).to be false
    expect(File.read(file1)).to eq(File.read(file2))
    expect(File.read(file1)).to eq(content) unless content.nil?
  end

  # Asserts that the two files are symlinks.
  def assert_symlinks(file1, file2, content: nil)
    expect(File.identical?(file1, file2)).to be true
    assert_file_content file1, content unless content.nil?
  end

  def assert_ran_unsuccessfully(exit_reason)
    expect(exit_reason).to_not be nil
  end

  def assert_ran_without_errors(exit_reason)
    expect(exit_reason).to be nil
    expect(@output_lines).to_not include(start_with 'E:')
  end

  def assert_ran_with_errors(exit_reason)
    expect(exit_reason).to be nil
    expect(@output_lines).to include(start_with 'E:')
  end

  def overwrite_choice
    instance_double('menu').tap do |menu|
      expect(cmd).to receive(:choose).and_yield menu
      expect(menu).to receive(:prompt=).with('Keep back up, restore, back up for all, restore for all?')
      allow(menu).to receive(:choice).with(:b)
      allow(menu).to receive(:choice).with(:r)
      allow(menu).to receive(:choice).with(:ba)
      allow(menu).to receive(:choice).with(:ra)
    end
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
    @exit_reason          = nil
    @default_restore_dir  = File.join(@tmpdir, 'machine')
    @dotfiles_dir         = File.join(@tmpdir, 'dotfiles')
    @apps_dir             = File.join(@dotfiles_dir, '_packages')
    @applications_path    = File.join(@apps_dir, 'applications.rb')
    @backups_path         = File.join(@dotfiles_dir, 'backups.rb')

    stub_const 'Dotfiler::APPLICATIONS', [
      Test::AppPackage,
      Test::BashPackage,
      Test::CodePackage,
      Test::GitPackage,
      Test::PythonPackage,
      Test::RubocopPackage,
      Test::VimPackage
    ]
    stub_const 'Dotfiler::Tasks::Package::DEFAULT_RESTORE_DIR', @default_restore_dir

    # Take over the interactions with console in order to stub out user interaction.
    allow(HighLine).to receive(:new).and_return cmd
    ENV['editor'] = 'vim'

    # Save existing packages.
    save_file_content ctx.restore_path('.test_vimrc'), '; Vim configuration.'
    save_file_content ctx.backup_path('code/_test_vscode'), 'some content'
    save_file_content ctx.restore_path('.test_vscode'), 'different content'
    save_file_content ctx.backup_path('bash/_test_bashrc'), 'bashrc file'
    save_file_content ctx.backup_path('python/_test_pythonrc'), 'pythonrc'
    save_file_content ctx.restore_path('.test_pythonrc'), 'pythonrc'
    save_file_content ctx.backup_path('rubocop/_test_rubocop'), 'rubocop'
    link_files ctx.backup_path('rubocop/_test_rubocop'), ctx.restore_path('.test_rubocop')

    # Overwrite the #pwd so that tests write to tmpdir and not the dotfiler dir.
    allow(Dir).to receive(:pwd).and_return @dotfiles_dir
  end

  describe '--help' do
    it do
      expected_usage = <<-USAGE.strip_heredoc
        Commands:
          dotfiler cleanup                       # Cleans up previous backups
          dotfiler help [COMMAND]                # Describe available commands or one specific command
          dotfiler init [<backups>...]           # Initializes backups
          dotfiler package <subcommand> ...ARGS  # Add/remove packages to be backed up
          dotfiler status                        # Returns the sync status
          dotfiler sync                          # Synchronize your settings

        Options:
          [--help], [--no-help]        # Print help for a specific command
          [--verbose], [--no-verbose]  # Print verbose information to stdout

      USAGE
      expect { dotfiler %w(--help) }.to output(expected_usage).to_stdout
    end
  end

  describe 'init' do
    let(:custom_path) { File.join(@tmpdir, 'custom') }
    let(:custom_ctx)  { ctx.with_backup_dir custom_path }

    it 'should initialize a backup in current working directory' do
      expect(Dir).to receive(:pwd).and_return custom_path

      assert_ran_without_errors dotfiler %w(init)
      assert_file_content custom_ctx.backup_path('backups.rb'), Dotfiler::Templates.backups
      assert_file_content custom_ctx.backup_path('sync.rb'), Dotfiler::Templates.sync
    end

    it 'should create a backup relative to the new dir' do
      expect(Dir).to receive(:pwd).and_return custom_path

      assert_ran_without_errors dotfiler %w(init ./package)
      assert_file_content custom_ctx.backup_path('package/backups.rb'), Dotfiler::Templates.backups
      assert_file_content custom_ctx.backup_path('package/sync.rb'), Dotfiler::Templates.sync
    end

    it 'should not create a backup if files already present' do
      expect(Dir).to receive(:pwd).and_return @dotfiles_dir

      assert_ran_without_errors dotfiler %w(init)
      expect(File.exist?(ctx.backup_path('backups.rb'))).to be false
      expect(File.exist?(ctx.backup_path('sync.rb'))).to be false
    end

    context 'when force specified' do
      it 'should create a backup even if files already present' do
        expect(Dir).to receive(:pwd).and_return @dotfiles_dir

        assert_ran_without_errors dotfiler %w(init --force)
        assert_file_content ctx.backup_path('backups.rb'), Dotfiler::Templates.backups
        assert_file_content ctx.backup_path('sync.rb'), Dotfiler::Templates.sync
      end
    end

    context 'when dir option specified' do
      it 'should initialize a backup at the location specified' do
        allow(Dir).to receive(:pwd).and_return @dotfiles_dir

        assert_ran_without_errors dotfiler %w(init), dir: custom_path
        assert_file_content custom_ctx.backup_path('backups.rb'), Dotfiler::Templates.backups
        assert_file_content custom_ctx.backup_path('sync.rb'), Dotfiler::Templates.sync
      end
    end
  end

  describe 'sync' do
    it 'should sync with restore overwrite' do
      save_file_content @backups_path, SAMPLE_BACKUP
      save_package_content @applications_path, nil, packages: %w(bash code python rubocop vim)

      expect(overwrite_choice).to receive(:choice).with(:r).and_yield
      assert_ran_with_errors dotfiler %w(sync --verbose), package: @backups_path

      expect(@output_lines.join).to eq <<-OUTPUT.strip_heredoc
        Syncing:
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
      OUTPUT

      assert_symlinks ctx.restore_path('.test_vimrc'), ctx.backup_path('vim/_test_vimrc')
      assert_symlinks ctx.restore_path('.test_vscode'), ctx.backup_path('code/_test_vscode'), content: 'different content'
      assert_symlinks ctx.restore_path('.test_bashrc'), ctx.backup_path('bash/_test_bashrc'), content: 'bashrc file'
      assert_symlinks ctx.restore_path('.test_pythonrc'), ctx.backup_path('python/_test_pythonrc')
    end

    it 'should sync with backup overwrite' do
      save_file_content @backups_path, SAMPLE_BACKUP
      save_package_content @applications_path, nil, packages: %w(bash code python rubocop vim)

      expect(overwrite_choice).to receive(:choice).with(:b).and_yield
      assert_ran_with_errors dotfiler %w(sync --verbose), package: @backups_path

      expect(@output_lines.join).to eq <<-OUTPUT.strip_heredoc
        Syncing:
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
      OUTPUT

      assert_symlinks ctx.restore_path('.test_vimrc'), ctx.backup_path('vim/_test_vimrc')
      assert_symlinks ctx.restore_path('.test_vscode'), ctx.backup_path('code/_test_vscode'), content: 'some content'
      assert_symlinks ctx.restore_path('.test_bashrc'), ctx.backup_path('bash/_test_bashrc'), content: 'bashrc file'
      assert_symlinks ctx.restore_path('.test_pythonrc'), ctx.backup_path('python/_test_pythonrc')
    end

    it 'should not sync if the task is disabled' do
      save_file_content @backups_path, SAMPLE_BACKUP
      save_package_content @applications_path, nil, packages: []
      assert_ran_without_errors dotfiler %w(sync), package: @backups_path

      expect(File.exist?(ctx.backup_path('vim/_test_vimrc'))).to be false
      assert_file_content ctx.backup_path('code/_test_vscode'), 'some content'
      assert_file_content ctx.restore_path('.test_vscode'), 'different content'
      expect(File.exist?(ctx.restore_path('.test_bashrc'))).to be false
      expect(File.identical?(ctx.restore_path('.test_pythonrc'), ctx.backup_path('python/_test_pythonrc'))).to be false
    end

    context 'when --copy' do
      it 'should generate file copies instead of symlinks' do
        save_file_content @backups_path, SAMPLE_BACKUP
        save_package_content @applications_path, nil, packages: %w(bash code python rubocop vim)

        expect(overwrite_choice).to receive(:choice).with(:r).and_yield
        assert_ran_with_errors dotfiler %w(sync --copy), package: @backups_path

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
      save_package_content @applications_path, nil, packages: %w(bash vim)
    end

    def create_cleanup_files
      cleanup_files.each { |path| save_file_content path, path }
      FileUtils.mkdir_p ctx.backup_path('bash/folder/nested/deeper')
    end

    it 'should report when there is nothing to clean' do
      save_file_content @backups_path, SAMPLE_BACKUP
      assert_ran_without_errors dotfiler %w(cleanup), package: @backups_path

      expect(@output_lines.join).to eq <<-OUTPUT.strip_heredoc
        Nothing to clean.
      OUTPUT
    end

    it 'should cleanup old backups' do
      save_file_content @backups_path, SAMPLE_BACKUP
      create_cleanup_files
      expect(cmd).to receive(:agree).twice.and_return true
      assert_ran_without_errors dotfiler %w(cleanup), package: @backups_path

      cleanup_files.each { |path| expect(File.exist?(path)).to be false }
      expect(@output_lines.join).to eq <<-OUTPUT.strip_heredoc
        Deleting \"#{ctx.backup_path('bash/setup-backup-1-_test_bash_local')}\"
        Deleting \"#{ctx.backup_path('vim/setup-backup-1-_test_vimrc')}\"
      OUTPUT
    end

    context 'when no options are passed in' do
      it 'should require confirmation' do
        save_file_content @backups_path, SAMPLE_BACKUP
        create_cleanup_files
        expect(cmd).to receive(:agree).twice.and_return false
        assert_ran_without_errors dotfiler %w(cleanup), package: @backups_path

        cleanup_files.each { |path| expect(File.exist?(path)).to be true }
      end
    end

    context 'when --confirm=false' do
      it 'should cleanup old backups' do
        save_file_content @backups_path, SAMPLE_BACKUP
        create_cleanup_files
        assert_ran_without_errors dotfiler %w(cleanup --confirm=false), package: @backups_path

        cleanup_files.each { |path| expect(File.exist?(path)).to be false }
      end
    end
  end

  describe 'status' do
    it 'should print an empty message if no packages exist' do
      assert_ran_without_errors dotfiler %w(status), package: ->(ctx) { ItemPackage.new ctx }

      expect(@output_lines.join).to eq <<-OUTPUT.strip_heredoc
        Current status:

        W: No packages enabled.
        W: Use ./dotfiler package add to enable packages.
      OUTPUT
    end

    it 'should print status' do
      save_package_content @applications_path, nil, packages: %w(bash code python rubocop vim)
      assert_ran_without_errors dotfiler %w(status), dir: @dotfiles_dir, package: ->(ctx) { ctx.package_from_files '_packages/*.rb' }

      expect(@output_lines.join).to eq <<-OUTPUT.strip_heredoc
        Current status:

        bash:
            .test_bashrc: needs sync
            .test_bash_local: no sources to synchronize
        code:
            .test_vscode: differs
        python:
            .test_pythonrc: needs sync
        rubocop:
            .test_rubocop: up to date
        vim:
            .test_vimrc: needs sync
      OUTPUT
    end

    it 'should print verbose status' do
      save_package_content @applications_path, nil, packages: %w(bash code python rubocop vim)
      assert_ran_without_errors dotfiler %w(status --verbose), dir: @dotfiles_dir, package: ->(ctx) { ctx.package_from_files '_packages/*.rb' }

      expect(@output_lines.join).to eq <<-OUTPUT.strip_heredoc
        Current status:

        bash:
            .test_bashrc: needs sync
            .test_bash_local: no sources to synchronize
        code:
            .test_vscode: differs
        python:
            .test_pythonrc: needs sync
        rubocop:
            .test_rubocop: up to date
        vim:
            .test_vimrc: needs sync
      OUTPUT
    end
  end

  describe 'package' do
    describe 'new' do
      it 'should create a new package' do
        save_backups_content @backups_path
        assert_ran_without_errors dotfiler %w(package new test)
        assert_package_content ctx.backup_path('_packages/test.rb'), 'test', []
        assert_file_content @backups_path, <<-SOURCE.strip_heredoc
          require 'dotfiler'

          class MyBackup < Dotfiler::Tasks::Package
            package_name ''

            def steps
              yield package_from_files #{File.join(@apps_dir, '*.rb')}
            end
          end
        SOURCE
      end

      it 'should not touch an existing package' do
        save_backups_content @backups_path
        save_package_content ctx.backup_path('_packages/test.rb'), 'test2', files: ['a']
        assert_ran_without_errors dotfiler %w(package new test)
        assert_package_content ctx.backup_path('_packages/test.rb'), 'test2', ['a']

        expect(@output_lines.join).to eq <<-OUTPUT.strip_heredoc
          Creating a package
          W: Package already exists
        OUTPUT
      end

      context 'when full path passed' do
        it 'should create a new package at that path' do
          save_backups_content @backups_path
          assert_ran_without_errors dotfiler %w(package new ./_pack/test.rb)
          assert_package_content ctx.backup_path('_pack/test.rb'), 'test', []
          assert_file_content @backups_path, <<-SOURCE.strip_heredoc
            require 'dotfiler'

            class MyBackup < Dotfiler::Tasks::Package
              package_name ''

              def steps
                yield package_from_files #{File.join(@dotfiles_dir, '_pack/*.rb')}
              end
            end
          SOURCE
        end
      end
    end

    describe 'add' do
      it 'should add packages' do
        save_backups_content @backups_path
        assert_ran_without_errors dotfiler %w(package add code vim)
        assert_file_content @backups_path, <<-SOURCE.strip_heredoc
          require 'dotfiler'

          class MyBackup < Dotfiler::Tasks::Package
            package_name ''

            def steps
              yield package 'code'
              yield package 'vim'
            end
          end
        SOURCE
      end

      it 'should not add invalid packages' do
        save_file_content @backups_path, Dotfiler::Templates.backups
        assert_ran_with_errors dotfiler %w(package add invalid)
        assert_file_content @backups_path, Dotfiler::Templates.backups

        expect(@output_lines.join).to eq <<-OUTPUT.strip_heredoc
          E: Package invalid not found
        OUTPUT
      end

      context 'when backups file missing' do
        it 'should not add any packages and print an error' do
          assert_ran_unsuccessfully dotfiler %w(package add code vim)
          expect(File.exist?(@backups_path)).to be false
        end
      end
    end

    describe 'remove' do
      it 'should remove packages' do
        save_file_content @backups_path, <<-SOURCE.strip_heredoc
          require 'dotfiler'

          class MyBackup < Dotfiler::Tasks::Package
            package_name ''

            def steps
              yield package 'code'
              yield package 'vim'
            end
          end
        SOURCE

        assert_ran_without_errors dotfiler %w(package remove code vim), package: @backups_path
        assert_file_content @backups_path, <<-SOURCE.strip_heredoc
          require 'dotfiler'

          class MyBackup < Dotfiler::Tasks::Package
            package_name ''

            def steps
            end
          end
        SOURCE
      end

      it 'should print an error when removing an invalid package' do
        save_file_content @backups_path, <<-SOURCE.strip_heredoc
          require 'dotfiler'

          class MyBackup < Dotfiler::Tasks::Package
            package_name ''

            def steps
              yield package 'code'
              yield package 'vim'
            end
          end
        SOURCE

        assert_ran_with_errors dotfiler %w(package remove invalid)
      end

      context 'when backups file missing' do
        it 'should not remove any packages and print an error' do
          assert_ran_unsuccessfully dotfiler %w(package remove code vim)
          expect(File.exist?(@backups_path)).to be false
        end
      end
    end

    describe 'discover' do
      it 'should list packages that can be added' do
        save_file_content @backups_path, SAMPLE_BACKUP
        assert_ran_without_errors dotfiler %w(package discover), package: ->(ctx) { ctx.package_from_files 'backups.rb' }

        expect(@output_lines.join).to eq <<-OUTPUT.strip_heredoc
          Discovered packages:
          bash
          code
          python
          rubocop
          vim
        OUTPUT
      end

      it 'should not list already added packages' do
        save_file_content @backups_path, SAMPLE_BACKUP
        save_file_content @applications_path, <<-SOURCE.strip_heredoc
          require 'dotfiler'

          class P < Dotfiler::Tasks::Package
            package_name 'p'

            def steps
              yield package 'bash'
              yield package 'code'
              yield package 'python'
              yield package 'rubocop'
              yield package 'vim'
            end
          end
        SOURCE

        assert_ran_without_errors dotfiler %w(package discover), package: ->(ctx) { ctx.package_from_files 'backups.rb' }
        expect(@output_lines.join).to eq <<-OUTPUT.strip_heredoc
          Discovered packages:
          No new packages discovered
        OUTPUT
      end
    end

    describe 'list' do
      it 'should list existing packages' do
        save_file_content @backups_path, SAMPLE_BACKUP
        save_package_content @applications_path, nil, packages: %w(bash code)
        assert_ran_without_errors dotfiler %w(package list)

        expect(@output_lines.join).to eq <<-OUTPUT.strip_heredoc
          Packages:
          bash
          code
        OUTPUT
      end
    end

    describe 'edit' do
      it 'should allow to edit a package' do
        save_package_content ctx.backup_path('_packages/test.rb'), 'test', files: []
        save_package_content @applications_path, nil, packages: %w(bash code python rubocop vim)
        expect(CONCRETE_IO).to receive(:system).with("vim #{File.join(@apps_dir, 'test.rb')}")
        assert_ran_without_errors dotfiler %w(package edit test), package: ->(ctx) { ctx.package_from_files '_packages/*.rb' }
      end

      it 'should edit global packages' do
        save_package_content ctx.backup_path('_packages/test.rb'), 'test', files: []
        save_package_content @applications_path, nil, packages: %w(bash code python rubocop vim)
        package_path = Test::BashPackage.instance_method(:steps).source_location[0]
        expect(CONCRETE_IO).to receive(:system).with("vim #{package_path}")

        assert_ran_without_errors dotfiler %w(package edit bash), package: ->(ctx) { ctx.package_from_files '_packages/*.rb' }
      end

      it 'should print a warning if package missing' do
        save_package_content ctx.backup_path('_packages/test.rb'), 'test', files: []
        save_package_content @applications_path, nil, packages: %w(bash code python rubocop vim)
        assert_ran_without_errors dotfiler %w(package edit unknown), package: ->(ctx) { ctx.package_from_files '_packages/*.rb' }

        expect(@output_lines.join).to eq("W: Could not find a package to edit. It might not have been added\n")
      end
    end
  end

  # Check that corrupting a file will make all commands fail.
  def assert_commands_fail_if_corrupt(corrupt_file_path, commands)
    save_file_content corrupt_file_path, "---\n"

    commands.each do |command|
      assert_ran_unsuccessfully dotfiler command.split(' ')
      expect(@exit_reason).to start_with("Could not load \"#{corrupt_file_path}\": ")
    end
  end

  context 'when a global config file is invalid' do
    it 'should fail commands' do
      commands = ['init', 'sync', 'cleanup', 'status', 'package add', 'package remove', 'package list', 'package edit foo']
      assert_commands_fail_if_corrupt @backups_path, commands
    end
  end

  context 'when a package is invalid' do
    it 'should fail commands' do
      save_file_content @backups_path, SAMPLE_BACKUP
      commands = %w(sync cleanup status)
      assert_commands_fail_if_corrupt File.join(@apps_dir, 'vim.rb'), commands
    end
  end
end
