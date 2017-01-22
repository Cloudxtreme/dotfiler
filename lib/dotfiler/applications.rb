require 'dotfiler/tasks/package'
require 'dotfiler/applications/atom'
require 'dotfiler/applications/bash'
require 'dotfiler/applications/byobu'
require 'dotfiler/applications/fish'
require 'dotfiler/applications/git'
require 'dotfiler/applications/intellij'
require 'dotfiler/applications/mysql'
require 'dotfiler/applications/nginx'
require 'dotfiler/applications/powershell'
require 'dotfiler/applications/slate'
require 'dotfiler/applications/sublime_text'
require 'dotfiler/applications/tmuxinator'
require 'dotfiler/applications/vim'
require 'dotfiler/applications/vscode'

module Dotfiler
  # List of packages for different applications.
  # These packages get automatically discovered when creating new backups.
  APPLICATIONS = [
    Dotfiler::Applications::AtomPackage,
    Dotfiler::Applications::BashPackage,
    Dotfiler::Applications::ByobuPackage,
    Dotfiler::Applications::FishPackage,
    Dotfiler::Applications::GitPackage,
    Dotfiler::Applications::IntelliJPackage,
    Dotfiler::Applications::MySQLPackage,
    Dotfiler::Applications::NginxPackage,
    Dotfiler::Applications::PowerShellPackage,
    Dotfiler::Applications::SlatePackage,
    Dotfiler::Applications::SublimeTextPackage,
    Dotfiler::Applications::TmuxinatorPackage,
    Dotfiler::Applications::VimPackage,
    Dotfiler::Applications::VsCodePackage
  ].freeze
end
