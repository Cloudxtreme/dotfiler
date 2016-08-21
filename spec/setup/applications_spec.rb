require 'setup/applications'
require 'setup/sync_context'
require 'setup/io'

module Setup

RSpec.describe APPLICATIONS do
  let(:ctx)    { SyncContext.create(DRY_IO).with_restore_to('/restore').with_backup_root('/backup') }

  # Check that requiring packages throws no exceptions.
  it 'should be valid packages' do
    under_windows { APPLICATIONS.map { |package| package.new ctx } }
    under_linux   { APPLICATIONS.map { |package| package.new ctx } }
    under_macos   { APPLICATIONS.map { |package| package.new ctx } }
  end
end

end
