require 'setup/applications'
require 'setup/sync_context'
require 'setup/io'

module Setup

RSpec.describe APPLICATIONS do
  let(:ctx)    { SyncContext.new backup_root: '/backup', restore_to: '/restore', io: DRY_IO }

  # Check that requiring packages throws no exceptions.
  it 'should be valid packages' do
    under_windows { APPLICATIONS.map { |package| package.new ctx } }
    under_linux   { APPLICATIONS.map { |package| package.new ctx } }
    under_macos   { APPLICATIONS.map { |package| package.new ctx } }
  end
end

end
