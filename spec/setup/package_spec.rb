# Tests file_backup.rb

require 'setup/package'
require 'setup/platform'
require 'setup/io'
require 'setup/tasks'

module Setup

RSpec.describe Package do
  let(:io)        { instance_double(InputOutput::File_IO, dry: false) }
  let(:task)      { instance_double(FileSyncTask) }
  let(:on_delete) { instance_double(Proc) }
  let(:ctx)       { SyncContext.new backup_dir: '/backup/root', restore_dir: '/restore/root', io: io, sync_time: 'sync_time', on_delete: on_delete }
  let(:linctx)    { ctx.with_restore_dir('/files').with_backup_dir('/backup/root/Package') }
  let(:winctx)    { ctx.with_restore_dir('/windows/files').with_backup_dir('/backup/root/Package') }
  let(:package)   { package_class.new(ctx) }

  # Lazily instantiated package example.
  let(:package_class) do
    Class.new(ItemPackage) do
      package_name 'Package'
      platforms [:WINDOWS]
      under_windows { restore_dir '/windows/files' }
      under_linux   { restore_dir '/files'}
      under_macos   { restore_dir '/macos/files' }

      def initialize(ctx)
        super
        under_linux { @items << file('.unknown') }
      end
    end
  end

  describe 'default package' do
    it 'should have an empty name' do
      default_package = Package.new winctx
      default_package.file 'a'

      expect(default_package.name).to eq('')
      expect(default_package.should_execute).to be true

      expect(default_package.to_a).to match_array []
    end
  end

  describe 'simple package' do
    it 'should sync single file' do
      package.items << package.file('a')

      expect(package.name).to eq('Package')
      expect(package.platforms).to eq [:WINDOWS]

      sync_items = package.to_a
      expect(sync_items).to match_array [an_instance_of(FileSyncTask)]
      expect(sync_items[0].backup_path).to eq(package.ctx.backup_path('a'))
    end
  end

  it 'should enter #under_macos under macos' do
    under_macos do
      expect(package.restore_dir).to eq('/macos/files')
    end
  end

  it 'should work under the same platform' do
    under_windows do
      expect(package.name).to eq('Package')
      expect(package.restore_dir).to eq('/windows/files')
      expect(package.should_execute).to be true
      expect(package.to_a).to eq []
    end
  end

  it 'should not work under a different platform' do
    under_linux do
      expect(package.name).to eq('Package')
      expect(package.restore_dir).to eq('/files')
      expect(package.should_execute).to be false

      sync_items = package.to_a
      expect(sync_items).to match_array [an_instance_of(FileSyncTask)]
      expect(sync_items[0].name).to eq '.unknown'
      expect(sync_items[0].backup_path).to eq(linctx.backup_path('_unknown'))
      expect(sync_items[0].file_sync_options).to eq({
        backup_path: linctx.backup_path('_unknown'),
        restore_path: linctx.restore_path('.unknown') })
    end
  end

  it 'should allow skipping' do
    under_windows do
      package.skip 'just because'
      expect(package.should_execute).to eq(false)
      expect(package.skip_reason).to eq('just because')
    end
  end

  it 'should allow adding sync items' do
    under_windows do
      package.items << package.file('.another')
      package.items << package.file('.another2').save_as('_anotherTwo')

      sync_items = package.to_a
      expect(sync_items).to match_array [an_instance_of(FileSyncTask), an_instance_of(FileSyncTask)]
      expect(sync_items[0].name).to eq('.another')
      expect(sync_items[0].backup_path).to eq(winctx.backup_path('_another'))
      expect(sync_items[0].file_sync_options).to eq({
        backup_path: winctx.backup_path('_another'),
        restore_path: winctx.restore_path('.another') })

      expect(sync_items[1].name).to eq('.another2')
      expect(sync_items[1].backup_path).to eq(winctx.backup_path('_anotherTwo'))
      expect(sync_items[1].file_sync_options).to eq({
        backup_path: winctx.backup_path('_anotherTwo'),
        restore_path: winctx.restore_path('.another2') })
    end
  end

  it 'should find cleanup files' do
    under_windows do
      package.items << package.file('a')
      package.items << package.file('b')
      expect(on_delete).to receive(:call).with(winctx.backup_path 'setup-backup-x-a').and_return false
      expect(io).to receive(:glob).with(winctx.backup_path('setup-backup-*-a')).and_return [
        File.expand_path(winctx.backup_path('setup-backup-x-a'))]

      expect(on_delete).to receive(:call).with(winctx.backup_path 'setup-backup-x-b').and_return true
      expect(io).to receive(:glob).with(winctx.backup_path('setup-backup-*-b')).and_return [
        File.expand_path(winctx.backup_path('setup-backup-x-b'))]
      expect(io).to receive(:rm_rf).with(winctx.backup_path 'setup-backup-x-b')

      package.cleanup!
    end
  end

  it 'should forward the message to all sync items' do
    under_windows do
      expect(FileSyncTask).to receive(:new).and_return task
      expect(task).to receive(:sync!).once
      expect(task).to receive(:should_execute).and_return true

      package.items << package.file('a')
      package.sync! {}
    end
  end
end

end # module Setup
