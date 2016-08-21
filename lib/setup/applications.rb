require 'setup/package'
require 'setup/applications/atom'
require 'setup/applications/bash'
require 'setup/applications/byobu'
require 'setup/applications/fish'
require 'setup/applications/git'
require 'setup/applications/intellij'
require 'setup/applications/mysql'
require 'setup/applications/nginx'
require 'setup/applications/powershell'
require 'setup/applications/slate'
require 'setup/applications/sublime_text'
require 'setup/applications/tmuxinator'
require 'setup/applications/vim'
require 'setup/applications/vscode'

module Setup

# List of packages for different applications.
# These packages get automatically discovered when creating new backups.
APPLICATIONS = [
  Applications::AtomPackage,
  Applications::BashPackage,
  Applications::ByobuPackage,
  Applications::FishPackage,
  Applications::GitPackage,
  Applications::IntelliJPackage,
  Applications::MySQLPackage,
  Applications::NginxPackage,
  Applications::PowerShellPackage,
  Applications::SlatePackage,
  Applications::SublimeTextPackage,
  Applications::TmuxinatorPackage,
  Applications::VimPackage,
  Applications::VsCodePackage
]

end
