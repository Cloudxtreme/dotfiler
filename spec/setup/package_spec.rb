# Tests file_backup.rb

require 'setup/package'
require 'setup/platform'
require 'setup/io'

module Setup

RSpec.describe Package do
  let(:io)        { instance_double(InputOutput::File_IO, dry: false) }
  let(:task)      { instance_double(FileSyncTask) }
  let(:ctx)       { SyncContext.new backup_root: '/backup/root', restore_to: '/restore/root', io: io, sync_time: 'sync_time' }
  let(:linctx)    { ctx.with_restore_to('/files').with_backup_root('/backup/root/Package') }
  let(:winctx)    { ctx.with_restore_to('/windows/files').with_backup_root('/backup/root/Package') }
  let(:package)   { package_class.new(ctx) }

  # Lazily instantiated package example.
  let(:package_class) do
    Class.new(Package) do
      package_name 'Package'
      platforms [:WINDOWS]
      under_windows { restore_to '/windows/files' }
      under_linux   { restore_to '/files'}
      under_macos   { restore_to '/macos/files' }

      def steps
        under_linux { file '.unknown' }
      end
    end
  end


  describe 'default package' do
    it 'should have an empty name' do
      default_package = Package.new winctx
      default_package.file 'a'

      expect(default_package.name).to eq('')
      expect(default_package.restore_to).to eq(nil)
      expect(default_package.platforms).to eq []
      expect(default_package.should_execute).to be true

      expect(default_package.sync_items).to match_array [an_instance_of(FileSyncTask)]
      expect(default_package.sync_items[0].backup_path).to eq(winctx.backup_path('a'))
    end
  end

  it 'should enter #under_macos under macos' do
    under_macos do
      expect(package.restore_to).to eq('/macos/files')
    end
  end

  it 'should work under the same platform' do
    under_windows do
      expect(package.name).to eq('Package')
      expect(package.restore_to).to eq('/windows/files')
      expect(package.should_execute).to be true
      expect(package.sync_items).to eq []
    end
  end

  it 'should not work under a different platform' do
    under_linux do
      expect(package.name).to eq('Package')
      expect(package.restore_to).to eq('/files')
      expect(package.should_execute).to be false
      expect(package.sync_items).to match_array [an_instance_of(FileSyncTask)]
      expect(package.sync_items[0].name).to eq '.unknown'
      expect(package.sync_items[0].backup_path).to eq(linctx.backup_path('_unknown'))
      expect(package.sync_items[0].file_sync_options).to eq({
        name: '.unknown',
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
      package.file('.another')
      package.file('.another2').save_as('_anotherTwo')
      expect(package.sync_items).to match_array [an_instance_of(FileSyncTask), an_instance_of(FileSyncTask)]
      expect(package.sync_items[0].name).to eq('.another')
      expect(package.sync_items[0].backup_path).to eq(winctx.backup_path('_another'))
      expect(package.sync_items[0].file_sync_options).to eq({
        name: '.another',
        backup_path: winctx.backup_path('_another'),
        restore_path: winctx.restore_path('.another') })

      expect(package.sync_items[1].name).to eq('.another2')
      expect(package.sync_items[1].backup_path).to eq(winctx.backup_path('_anotherTwo'))
      expect(package.sync_items[1].file_sync_options).to eq({
        name: '.another2',
        backup_path: winctx.backup_path('_anotherTwo'),
        restore_path: winctx.restore_path('.another2') })
    end
  end

  it 'should find cleanup files' do
    under_windows do
      expect(io).to receive(:glob).twice.with(winctx.backup_path('**/*')).and_return [
        File.expand_path(winctx.backup_path('a')),
        File.expand_path(winctx.backup_path('a/file')),
        File.expand_path(winctx.backup_path('b')),
        File.expand_path(winctx.backup_path('b/subfile')),
        File.expand_path(winctx.backup_path('setup-backup-file'))]

      package.file 'a'
      expect(package.cleanup).to eq([File.expand_path(winctx.backup_path('setup-backup-file'))])

      package_untracked = package_class.new ctx.with_options untracked: true
      package_untracked.file 'a'
      expect(package_untracked.cleanup).to eq([
        File.expand_path(winctx.backup_path('b')),
        File.expand_path(winctx.backup_path('setup-backup-file'))])
    end
  end

  it 'should forward the message to all sync items' do
    under_windows do
      expect(FileSyncTask).to receive(:new).and_return task
      expect(task).to receive(:sync!).once

      package.file 'a'
      package.sync! {}
    end
  end
end

end # module Setup
