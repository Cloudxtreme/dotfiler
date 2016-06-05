require 'setup/file_sync'

module Setup

class FileSyncTask
  attr_reader :name

  def initialize(file_sync_options, ctx)
    @file_sync_options = file_sync_options
    @file_sync_options[:copy] = ctx[:copy] if ctx[:copy]
    @file_sync_options[:on_overwrite] = ctx[:on_overwrite] if ctx[:on_overwrite]

    @name = file_sync_options[:name]
    @ctx = ctx
  end

  def sync!
    file_sync_options = @file_sync_options
    FileSync.new(@ctx[:sync_time], @ctx[:io]).sync! file_sync_options
  end

  def info
    file_sync_options = @file_sync_options
    FileSync.new(@ctx[:sync_time], @ctx[:io]).info file_sync_options
  end
end

end
