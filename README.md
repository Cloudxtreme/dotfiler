About:
======

Scriptable backup library.
Setup is a library to backup your settings.
Once you configure one of your machines use setup and apply the configuration to all machines.

Setup can store configuration even if you do not want to apply it to all machines.

Features:
---------

* Synchronizes configuration for many applications out of the box
* Synchronizes settings accross os'es:
    * Allows to share settings accross os'es (sublime text)
    * Allows to split settings accross os'es (.gitconfig)
* Synchronization tasks are scriptable - Write your own tasks to synchronize wallpapers/registry settings, etc...
* Handles multiple backup directories - have a separate directory for public github configuration and private onedrive configuration
* Supports dry run - before you sync you can
    * Check what will be synced status
    * Dry run to check the commands being executed
* 100% test coverage for product code

# Installation

Current work items:

1. [x] Figure out how to ask questions by FileSync. (on_overwrite option)
2. [x] Complete the `sync` command. Make it ask for action on any collisions.
3. [ ] Make `sync` more resilient to IO errors. Especially when the symlink exists on the other end but points to an invalid location.
4. [x] Replace backup/restore with `sync`.
5. [x] Implement package new/edit to make it faster to add new settings.
6. [x] Convert packages into enabled/new/ignored.
   Enabled packages already have some data backed up.
   New packages are yet to be backed up.
   Ignored packages are the ones for which sync should be skipped.
7. [ ] Update discovery/enabling/disabling behavior.
    1. [ ] Discover only on init and discovery.
8. [x] Try to make it possible to define packages via ruby scripts.
    1. [x] Resolve all package tasks as FileSyncTask
    2. [x] Create Package from which Package derives
    3. [x] Use Package by CLI
    4. [x] Allow to load Packages by Backup manager
    5. [x] Covert all applications to Package instances
    6. [x] Drop the support for yaml config files
    7. [x] Simplify label handling
9. [x] Rename task to package throughout the code.
10. [x] Simplify sync_context generation and passing (decrease the number of call to #with_options)
11. [x] Move applications into `lib`
12. [x] Add a namespace to applications packages
13. [x] Do not treat APPLICATIONS_DIR specially
14. [x] Load files via `applications.rb`
15. [x] Make package management/discovery edit the `applications.rb` file
16. [x] Drop `config.yml` file
14. [ ] Do an API review?
* [ ] Update tests to match the new APIs
* [ ] Complete the TODOs inside of code
* [ ] Complete readme
* [ ] Think of the name for the gem
* [ ] Publish the gem

TODOS:
1. [x] Refactor to enable end-to-end experience
2. [x] Add unit and integration tests to make sure the code works
3. [x] Allow to add globs for files
5. [x] Try to add support for defaults/git repositories/registry keys

Discovery:
==========

First use experience should allow to fetch existing backups from `applications`.
It should still be easy to add/edit/remove these.

When do we discover?:
---------------------

Discovery should occur....

when starting a new backup or when setup gets updated
you can always check the applications.rb file to determine if discovery should be disabled.

* How to resolve cross backup packages?
* How to sync a specific task? `setup sync ./dotfiles/home-profile/_packages/vim.rb` or `setup sync vim`

```ruby
setup sync drognanar/dotfiles/vim
setup sync another/dotfiles/vim
```

Importing core applications:
----------------------------

Have a `applications.rb` file inside of a backup and import core applications.

```ruby
require 'setup/applications'

# What is the relevant way to import?
Vim = Setup::Applications::Vim
SublimeText = Setup::Applications::SublimeText
``` 

Importing external backups:
---------------------------

Requires a global backup manager?
Backup manager needs an update then.
Unless Backup/Package manager can include backups/packages from a file.

```ruby
# Backup.rb
import_backup url: 'https://github.com/drognanar/anotherbackup'
backup = BACKUPS.import url: 'https://github.com/drognanar/anotherbackup'
Vim = backup.get_package 'vim'
```

```ruby
# Have an install script which allows to import other backups.
# And enable them.
# Imports globally another backup
import_backup url: 'https://github.com/drognanar/anotherbackup'
# Do you still need global config.json?

# Imports just a single package from another backup
import_package url: 'https://github.com/drognanar/anotherbackup/master/_packages/file.rb'

class Package
    event :after_steps_loaded

    def steps
    end
end

class Backup
    event :after_packages_loaded

    def packages
    end
end
```

How to import backup and run a subset of packages? 
