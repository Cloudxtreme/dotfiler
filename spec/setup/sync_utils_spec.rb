require 'setup/sync_utils'
require 'setup/sync_context'
require 'setup/sync_status'

require 'pathname'
require 'yaml/store'

module Setup
  RSpec.describe SyncUtils do
    let(:io)             { instance_double(InputOutput::FileIO, dry: false) }
    let(:ctx)            { SyncContext.new io: io }

    describe '#create_backup!' do
      it 'should create backup if directory does not exist' do
        expect(io).to receive(:exist?).with('/backup/dir').ordered.and_return false
        expect(io).to receive(:mkdir_p).with('/backup/dir')
        expect(io).to receive(:write).with('/backup/dir/backups.rb', Templates.backups)
        expect(io).to receive(:write).with('/backup/dir/sync.rb', Templates.sync)

        SyncUtils.create_backup '/backup/dir', ctx.logger, io
      end

      it 'should create backup if force passed' do
        expect(io).to receive(:exist?).with('/backup/dir').ordered.and_return true
        expect(io).to receive(:entries).with('/backup/dir').ordered.and_return []
        expect(io).to receive(:mkdir_p).with('/backup/dir')
        expect(io).to receive(:write).with('/backup/dir/backups.rb', Templates.backups)
        expect(io).to receive(:write).with('/backup/dir/sync.rb', Templates.sync)

        SyncUtils.create_backup '/backup/dir', ctx.logger, io
      end

      it 'should not create backup if backup directory is not empty' do
        expect(io).to receive(:exist?).with('/backup/dir').ordered.and_return true
        expect(io).to receive(:entries).with('/backup/dir').ordered.and_return ['a']

        SyncUtils.create_backup '/backup/dir', ctx.logger, io
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

        SyncUtils.create_backup '/backup/dir', ctx.logger, io, force: true
      end
    end

    describe '#discover_packages' do
      it 'should include packages' do
        package = instance_double(Package, data?: true)
        root_package = ItemPackage.new ctx
        ctx.packages['a'] = package

        expect(SyncUtils.discover_packages(root_package)).to eq ['a']
      end

      it 'should not include packages with no data' do
        package = ItemPackage.new ctx
        root_package = ItemPackage.new ctx

        ctx.packages['a'] = package

        expect(SyncUtils.discover_packages(root_package)).to eq []
      end

      it 'should not include already existing packages' do
        package = instance_double(Package, data?: true, name: 'a')
        root_package = ItemPackage.new ctx
        root_package.items << package

        ctx.packages['a'] = package

        expect(SyncUtils.discover_packages(root_package)).to eq []
      end

      it 'should not include an already existing nested package' do
        package1 = instance_double(Package, data?: true, name: 'a')
        package2 = ItemPackage.new ctx
        package2.items << package1
        root_package = ItemPackage.new ctx
        root_package.items << package2

        ctx.packages['a'] = package1

        expect(SyncUtils.discover_packages(root_package)).to eq []
      end
    end

    describe '#get_status_str' do
      it 'should get status for SyncStatus' do
        status = SyncStatus.new 'name', :no_sources
        expect(SyncUtils.get_status_str(status)).to eq("name: no sources to synchronize\n")
      end

      it 'should print itself and subitems' do
        status1 = SyncStatus.new 'name1', :up_to_date
        status2 = SyncStatus.new 'name2', :no_sources
        group = GroupStatus.new 'group', [status1, status2]
        expect(SyncUtils.get_status_str(group)).to eq(
'group:
    name1: up to date
    name2: no sources to synchronize
')
      end

      it 'should handle subgroups' do
        status1 = SyncStatus.new 'name1', :up_to_date
        status2 = SyncStatus.new 'name2', :no_sources
        status3 = SyncStatus.new 'name3', :backup
        group1 = GroupStatus.new 'group1', [status1, status2]
        group = GroupStatus.new 'group', [group1, status3]
        expect(SyncUtils.get_status_str(group)).to eq(
'group:
    group1:
        name1: up to date
        name2: no sources to synchronize
    name3: needs sync
')
      end

      it 'should collapse empty names' do
        status1 = SyncStatus.new 'name1', :up_to_date
        status2 = SyncStatus.new 'name2', :no_sources
        status3 = SyncStatus.new 'name3', :backup
        status4 = SyncStatus.new 'name4', :restore
        status5 = SyncStatus.new 'name5', :resync
        status6 = SyncStatus.new 'name6', :overwrite_data
        group1 = GroupStatus.new '', [status1, status2]
        group2 = GroupStatus.new 'group2', [status3]
        group3 = GroupStatus.new 'group3', [status4, status5, group2]
        group = GroupStatus.new nil, [group1, group3, status6]
        expect(SyncUtils.get_status_str(group)).to eq(
'name1: up to date
name2: no sources to synchronize
group3:
    name4: needs sync
    name5: needs sync
    group2:
        name3: needs sync
name6: differs
')
      end
    end
  end
end # module Setup
