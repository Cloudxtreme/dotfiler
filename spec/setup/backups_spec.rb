require 'setup/backups'
require 'setup/sync_context'

require 'pathname'
require 'yaml/store'

module Setup
  RSpec.describe Backups do
    let(:io)             { instance_double(InputOutput::FileIO, dry: false) }
    let(:ctx)            { SyncContext.new io: io }

    describe '#create_backup!' do
      it 'should create backup if directory does not exist' do
        expect(io).to receive(:exist?).with('/backup/dir').ordered.and_return false
        expect(io).to receive(:mkdir_p).with('/backup/dir')
        expect(io).to receive(:write).with('/backup/dir/backups.rb', Templates.backups)
        expect(io).to receive(:write).with('/backup/dir/sync.rb', Templates.sync)

        Backups.create_backup '/backup/dir', ctx.logger, io
      end

      it 'should create backup if force passed' do
        expect(io).to receive(:exist?).with('/backup/dir').ordered.and_return true
        expect(io).to receive(:entries).with('/backup/dir').ordered.and_return []
        expect(io).to receive(:mkdir_p).with('/backup/dir')
        expect(io).to receive(:write).with('/backup/dir/backups.rb', Templates.backups)
        expect(io).to receive(:write).with('/backup/dir/sync.rb', Templates.sync)

        Backups.create_backup '/backup/dir', ctx.logger, io
      end

      it 'should not create backup if backup directory is not empty' do
        expect(io).to receive(:exist?).with('/backup/dir').ordered.and_return true
        expect(io).to receive(:entries).with('/backup/dir').ordered.and_return ['a']

        Backups.create_backup '/backup/dir', ctx.logger, io
        expect(@log_output.readlines.join).to eq(
"Creating a backup at \"/backup/dir\"
W: Cannot create backup. The folder /backup/dir already exists and is not empty.
")
      end

      it 'should create backup if force passed' do
        expect(io).to receive(:exist?).with('/backup/dir').ordered.and_return true
        expect(io).to receive(:entries).with('/backup/dir').ordered.and_return ['a']
        expect(io).to receive(:mkdir_p).with('/backup/dir')
        expect(io).to receive(:write).with('/backup/dir/backups.rb', Templates.backups)
        expect(io).to receive(:write).with('/backup/dir/sync.rb', Templates.sync)

        Backups.create_backup '/backup/dir', ctx.logger, io, force: true
      end
    end

    describe '#discover_packages' do
      it 'should include packages' do
        package = instance_double(Package, data?: true)
        root_package = ItemPackage.new ctx
        ctx.packages['a'] = package

        expect(Backups.discover_packages(root_package)).to eq ['a']
      end

      it 'should not include packages with no data' do
        package = ItemPackage.new ctx
        root_package = ItemPackage.new ctx

        ctx.packages['a'] = package

        expect(Backups.discover_packages(root_package)).to eq []
      end

      it 'should not include already existing packages' do
        package = instance_double(Package, data?: true, name: 'a')
        root_package = ItemPackage.new ctx
        root_package.items << package

        ctx.packages['a'] = package

        expect(Backups.discover_packages(root_package)).to eq []
      end

      it 'should not include an already existing nested package' do
        package1 = instance_double(Package, data?: true, name: 'a')
        package2 = ItemPackage.new ctx
        package2.items << package1
        root_package = ItemPackage.new ctx
        root_package.items << package2

        ctx.packages['a'] = package1

        expect(Backups.discover_packages(root_package)).to eq []
      end
    end
  end
end # module Setup
