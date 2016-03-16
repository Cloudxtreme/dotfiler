# This tests the overall appliction integration test.
require 'setup/cli'
require 'setup/io'

module Setup

RSpec.describe Cli::SetupCLI do
  describe 'get_io' do
    it 'should dry run when passing the dry option' do
      expect(Cli::SetupCLI.new.get_io dry: true).to eq(DRY_IO)
    end

    it 'should concrete run without passing the dry option' do
      expect(Cli::SetupCLI.new.get_io).to eq(CONCRETE_IO)
    end
  end

  describe 'resolve_backups' do
  end
end

# Integration tests.
RSpec.describe './setup' do
  describe 'init' do
    setup_cli = Cli::SetupCLI.new
    puts setup_cli
    # setup_cli.options = {output: ''}
    # setup_cli.init 'file:///drognanar/field', 'b'
    # setup_cli.init 'git://url'

    # puts '--create_single_dir'
    # puts '--out=dir'
    # puts '--name=n'
    # puts 'setup init [paths...] [--create_single_dir] [--out=dir] [--name=name]'
    # puts 'setup init a --out=b; setup init c --out=d; setup init e --out=f; setup init g --out=h; setup init i -o j'
  end

  describe 'backup' do
  end

  describe 'restore' do
  end

  describe 'cleanup' do
  end

  describe 'status' do
    it 'should print status' do
    end
  end

  describe 'app' do
    describe 'add' do
    end

    describe 'remove' do
    end

    describe 'list' do
    end
  end
end

end # module Setup
