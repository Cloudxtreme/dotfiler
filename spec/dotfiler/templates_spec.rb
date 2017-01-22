require 'dotfiler/applications'
require 'dotfiler/templates'

module Dotfiler
  module Templates
    RSpec.describe 'package' do
      it 'should get a package' do
        expect(Dotfiler::Templates.package('app', files: %w(file1 file2), packages: %w(vim))).to eq(
'require \'dotfiler\'

class AppPackage < Dotfiler::Tasks::Package
  package_name \'app\'

  def steps
    yield file \'file1\'
    yield file \'file2\'
    yield package \'vim\'
  end
end
')
      end
    end
  end
end
