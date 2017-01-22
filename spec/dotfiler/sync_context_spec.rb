require 'dotfiler/tasks/package'
require 'dotfiler/sync_context'

RSpec.describe SyncContext do
  let(:time)        { Time.new }
  let(:reporter)    { Reporter.new }
  let(:backup_dir)  { File.expand_path '/backup/dir' }
  let(:restore_dir) { File.expand_path '/restore/dir' }
  let(:package)     { ItemPackage.new SyncContext.new }
  let(:options)     do
    {
      io: DRY_IO,
      sync_time: time,
      backup_dir: '/backup/dir',
      restore_dir: '/restore/dir',
      reporter: reporter,
      logger: Logging.logger['Test'],
      packages: { package.name => package }
    }
  end
  let(:ctx) { SyncContext.new options.dup }

  describe '#initialize' do
    it 'should initialize default options' do
      expect(Time).to receive(:new).and_return time
      expect(Reporter).to receive(:new).and_return reporter
      ctx = SyncContext.new

      expect(ctx.io).to eq CONCRETE_IO
      expect(ctx.options[:sync_time]).to eq(time)
      expect(ctx.options[:backup_dir]).to eq('')
      expect(ctx.options[:restore_dir]).to eq('')
      expect(ctx.reporter).to eq(reporter)
      expect(ctx.logger).to eq(Logging.logger['Dotfiler'])
      expect(ctx.packages).to eq({})
    end

    it 'should use DRY_IO in dry mode' do
      ctx = SyncContext.new dry: true
      expect(ctx.io).to eq(DRY_IO)
    end

    it 'should allow to override options' do
      expect(ctx.io).to eq(DRY_IO)
      expect(ctx.options[:sync_time]).to eq(time)
      expect(ctx.options[:backup_dir]).to eq('/backup/dir')
      expect(ctx.options[:restore_dir]).to eq('/restore/dir')
      expect(ctx.reporter).to eq(reporter)
      expect(ctx.logger).to eq(Logging.logger['Test'])
      expect(ctx.packages).to eq(package.name => package)
    end
  end

  describe '#dup' do
    it 'should hard copy an item' do
      ctx2 = ctx.dup
      ctx2.options[:io] = CONCRETE_IO
      ctx2.options[:backup_dir] = '/backup/dir2'

      expect(ctx.options[:io]).to eq(DRY_IO)
      expect(ctx.options[:backup_dir]).to eq('/backup/dir')
      expect(ctx2.options[:io]).to eq(CONCRETE_IO)
      expect(ctx2.options[:backup_dir]).to eq('/backup/dir2')
    end
  end

  describe '#with_options' do
    it 'should create a new item with new options' do
      ctx2 = ctx.with_options backup_dir: '/backup/dir2', restore_dir: '/restore/dir2'
      expect(ctx.options[:backup_dir]).to eq('/backup/dir')
      expect(ctx.options[:restore_dir]).to eq('/restore/dir')
      expect(ctx2.options[:backup_dir]).to eq('/backup/dir2')
      expect(ctx2.options[:restore_dir]).to eq('/restore/dir2')
    end
  end

  describe '#with_backup_dir' do
    it 'should create a new SyncContext with a new backup dir' do
      ctx2 = ctx.with_backup_dir '/backup/dir2'
      expect(ctx2.options[:backup_dir]).to eq(File.expand_path('/backup/dir2'))
    end

    it 'should create a new SyncContext with a relative backup dir' do
      ctx2 = ctx.with_backup_dir './subdir'
      expect(ctx2.options[:backup_dir]).to eq(File.expand_path('/backup/dir/subdir'))
    end
  end

  describe '#with_restore_dir' do
    it 'should create a new SyncContext with a new restore dir' do
      ctx2 = ctx.with_restore_dir '/restore/dir2'
      expect(ctx2.options[:restore_dir]).to eq(File.expand_path('/restore/dir2'))
    end

    it 'should create a new SyncContext with a relative restore dir' do
      ctx2 = ctx.with_restore_dir './subdir'
      expect(ctx2.options[:restore_dir]).to eq(File.expand_path('/restore/dir/subdir'))
    end
  end

  describe '#with_packages' do
    it 'should create a new SyncContext with new packages' do
      package2 = ItemPackage.new ctx
      ctx2 = ctx.with_packages(package2.name => package2)
      expect(ctx2.packages).to eq(package2.name => package2)
    end
  end

  describe '#backup_path' do
    it 'should compute backup path relative to the backup dir' do
      ctx = SyncContext.new restore_dir: restore_dir, backup_dir: backup_dir
      expect(ctx.backup_path).to eq(backup_dir)
      expect(ctx.backup_path('subfolder')).to eq(File.join(backup_dir, 'subfolder'))
    end
  end

  describe '#restore_path' do
    it 'should compute restore path relative to the restore dir' do
      ctx = SyncContext.new restore_dir: restore_dir, backup_dir: backup_dir
      expect(ctx.restore_path).to eq(restore_dir)
      expect(ctx.restore_path('subfolder')).to eq(File.join(restore_dir, 'subfolder'))
    end
  end
end
