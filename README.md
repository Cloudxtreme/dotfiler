About
=====

Dotfiler is a API for creating scripts that sync dotfiles on your machine, such as the one below:

```ruby
#!/usr/bin/env ruby

require 'dotfiler'

# Define what do you want to do when synchronizing your dotfiles.
class MyBackup << Dotfiler::Tasks::Package
  def steps
    # Synchronize files
    yield file('.bashrc')
    yield file('.vimrc').save_as('vimrc')

    # Synchronize data only on specific OSes/machines
    under_windows    { yield file('Documents/WindowsPowerShell') }
    under_tag(:work) { yield file('.bash_aliases').save_as('bash_aliases_for_work.sh') }

    # Synchronize packages provided with dotfiler (vim/sublime text/atom/etc...)
    yield all_packages

    # Execute a custom script
    yield run do
      `ssh-keygen -t rsa -b 4096 -C "<your_email>"` unless File.exist? '~/.ssh'
    end
  end
end

# Start the CLI
Dotfiler::Cli::Program.start ARGV, package: MyBackup
```

This library provides ready made packages to synchronize setting for common applications.
Several of these packages work in a cross platform manner (your Sublime Settings will roam between your Windows, Linux and Mac OS machine).

You can always create custom packages as the one above to extend the synchronization behavior.

Getting started
===============

To create a basic folder structure type:

```
dotfiler init
```

Then edit the `backups.rb` file to add the files/packages you want to synchronize.

Finally run the following in order to synchronize files:

```
ruby sync.rb sync
```

Copyright
=========

Dotfiler (c) 2017 made by Artur Spychaj. Provided under MIT license. See [LICENSE](http://github.com/drognanar/dotfiler/LICENSE).
