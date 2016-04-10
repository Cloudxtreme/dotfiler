What is better than mackup?
===========================

Allows to sync the same file between osx/win/lin (sublime text)
Allows to sync one file (.gitconfig) to different locations for different os'es
Allows to have multiple backup dirs (one for github and one for onedrive)
Allows to see the status
Allows to dry run
Has 100% test coverage

Would like to have registry/local files support.
Would like to have sync scripts.

# This is a cross platform Mackup

This is a backup mechanism.
It allows to synchronise settings across machines and across platforms.
Out of the box setup synchronizes common applications.

? It also supports mackup configuration.
? It also allows to backup local files as well.

# Installation

Current work items:

1. [x] Figure out how to ask questions by FileSync. (on_overwrite option) 
2. [x] Complete the `sync` command. Make it ask for action on any collisions.
3. [ ] Make `sync` more resilient to IO errors.
4. [x] Replace backup/restore with `sync`.
5. [x] Implement package new/edit to make it faster to add new settings.
6. [ ] Convert packages into enabled/new/ignored.
       Enabled packages already have some data backed up.
       New packages are yet to be backed up.
       Ignored packages are the ones for which sync should be skipped.
7. [ ] Update discovery behaviour. Discover only on init and discovery.
8. [ ] Try to make it possible to define packages via ruby scripts.
       This can resolve all problems with regards to resolution.
       This requires some plugin architecture.
9. [ ] Rename task to package throughout the code.

TODOS:
1. [x] Refactor to enable end-to-end experience
2. [x] Add unit and integration tests to make sure the code works
3. [ ] Allow to add globs for files
4. [ ] Complete the TODOs inside of code
5. [ ] Try to add support for defaults/git repositories/registry keys
6. [ ] Complete readme
7. [ ] Think of the name for the gem
8. [ ] Publish the gem

Plugin architecture
===================

```ruby
class PackageLoader
include Singleton

registered_packages = []
end
```

```ruby
new_package do |c|
    name = 'git'
    files = []
end
```

```ruby
class GitPackage < Package
    name = 'git'
    files = []
end
```

Design questions?
=================

_how to handle multiple backups and restores?_
_how to handle when root is relative?_