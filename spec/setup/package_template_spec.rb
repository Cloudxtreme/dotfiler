require 'setup/applications'
require 'setup/package_template'

module Setup
module Templates

RSpec.describe 'package' do
  it 'should get a package' do
    expect(Setup::Templates::package 'app', ['file1', 'file2']).to eq(
'class AppPackage < Setup::Package
  package_name \'App\'

  def steps
    file \'file1\'
    file \'file2\'
  end
end
')
  end
end

RSpec.describe 'applications' do
  it 'should generate an applications template' do
    expect(Setup::Templates::applications [Applications::VimPackage, Applications::GitPackage]).to eq(
'VimPackage = Setup::Applications::VimPackage
GitPackage = Setup::Applications::GitPackage
')
  end
end

end
end