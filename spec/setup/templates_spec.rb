require 'setup/applications'
require 'setup/templates'

module Setup
  module Templates
    RSpec.describe 'package' do
      it 'should get a package' do
        expect(Setup::Templates.package('app', files: %w(file1 file2))).to eq(
'require \'setup\'

class AppPackage < Setup::Tasks::Package
  package_name \'app\'

  def steps
    yield file \'file1\'
    yield file \'file2\'
  end
end
')
      end
    end

    RSpec.describe 'applications' do
      it 'should generate an applications template' do
        expect(Setup::Templates.applications([Applications::VimPackage, Applications::GitPackage])).to eq(
'VimPackage = Setup::Applications::VimPackage
GitPackage = Setup::Applications::GitPackage
')
      end
    end
  end # module Templates
end # module Setup
