require 'setup/applications'
require 'setup/package_template'

module Setup

RSpec.describe 'get_package' do
  it 'should get a package' do
    expect(Setup::get_package 'app', ['file']).to eq(
'class AppPackage < Setup::Package
  package_name \'App\'

  def steps
    file \'file\'
  end
end
')
  end
end

RSpec.describe 'get_applications' do
  it 'should generate an applications template' do
    expect(Setup::get_applications [VimPackage, GitPackage]).to eq(
'VimPackage = VimPackage
GitPackage = GitPackage
')
  end
end

end