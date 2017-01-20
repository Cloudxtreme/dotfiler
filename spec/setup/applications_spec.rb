require 'setup/applications'
require 'setup/sync_context'
require 'setup/io'

module Setup
  RSpec.describe APPLICATIONS do
    let(:ctx) { SyncContext.new backup_dir: '/backup', restore_dir: '/restore', io: DRY_IO }

    def validate_applications
      APPLICATIONS
        .map { |package_cls| package_cls.new ctx }
        .map { |package| expect(package.to_a.length).to be >= 1 }
    end

    # Check that requiring packages throws no exceptions.
    it 'should be valid packages' do
      under_windows { validate_applications }
      under_linux   { validate_applications }
      under_macos   { validate_applications }
    end
  end
end # module Setup
