require 'dotfiler/applications'
require 'dotfiler/templates'

module Dotfiler
  module Templates
    RSpec.describe 'package' do
      it 'should get a package' do
        expect(Dotfiler::Templates.package('app', files: %w(file1 file2))).to eq(
'require \'dotfiler\'

class AppPackage < Dotfiler::Tasks::Package
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
        expect(Dotfiler::Templates.applications([Applications::VimPackage, Applications::GitPackage])).to eq(
'VimPackage = Dotfiler::Applications::VimPackage
GitPackage = Dotfiler::Applications::GitPackage
')
      end
    end
  end
end
