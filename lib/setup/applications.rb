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

# TODO(drognanar): Prefix these with Setup:: namespace.
# List of packages for different applications.
# These packages get automatically discovered when creating new backups.
APPLICATIONS = [
  AtomPackage,
  BashPackage,
  ByobuPackage,
  FishPackage,
  GitPackage,
  IntelliJPackage,
  MySQLPackage,
  NginxPackage,
  PowerShellPackage,
  SlatePackage,
  SublimeTextPackage,
  TmuxinatorPackage,
  VimPackage,
  VsCodePackage
]

end
