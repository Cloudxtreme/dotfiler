# This tests the overall appliction integration test.
require 'setup/cli'
require 'setup/io'

module Setup

$thor_runner = true

RSpec.describe Cli::AppCLI do
  let(:app_cli) { Cli::AppCLI.new }
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
  let(:setup_cli) { Cli::SetupCLI.new }
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
  let(:io) { Setup::CONCRETE_IO }
  let(:dry_io) { Setup::DRY_IO }

  describe './setup --help' do
    it { capture(:stdout) { Cli::SetupCLI.start %w[--help] } }
  end

  describe './setup init' do
    it 'should work'

    # TODO: create a temp directory.
    # TODO: you might need to mock io operations (git clone)
    # TODO: then deal with the rest of the filesystem
  end

  describe 'init' do
  end

  describe './setup backup' do
  end

  describe './setup restore' do
  end

  describe './setup cleanup' do
  end

  describe './setup status' do
    it 'should print status' do
    end
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
