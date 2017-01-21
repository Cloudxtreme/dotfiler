require 'setup/tasks/package'
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
    Setup::Applications::AtomPackage,
    Setup::Applications::BashPackage,
    Setup::Applications::ByobuPackage,
    Setup::Applications::FishPackage,
    Setup::Applications::GitPackage,
    Setup::Applications::IntelliJPackage,
    Setup::Applications::MySQLPackage,
    Setup::Applications::NginxPackage,
    Setup::Applications::PowerShellPackage,
    Setup::Applications::SlatePackage,
    Setup::Applications::SublimeTextPackage,
    Setup::Applications::TmuxinatorPackage,
    Setup::Applications::VimPackage,
    Setup::Applications::VsCodePackage
  ].freeze
end # module Setup
