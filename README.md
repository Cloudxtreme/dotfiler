About
=====

Dotfiler is a library that allows you to create scripts for syncing dotfiles on your machine, such as the one below:

```ruby
#!/usr/bin/env ruby

# Define what do you want to do when synchronizing your dotfiles.
class MyBackup << Dotfiler::Tasks::Package
  def steps
    yield file('.bashrc')
    yield file('.vimrc')

    under_windows    { yield file('Documents/WindowsPowerShell') }
    under_tag(:work) { yield file('.bash_aliases').save_as('work_aliases.sh') }

    yield package('firefox') # Synchronize one of provided packages
    yield package('vim')
    yield package('emacs')

    run do # Execute a custom script
      `ssh-keygen -t rsa -b 4096 -C "<your_email>"` unless File.exist? '~/.ssh'
    end
  end
end

# Start the CLI
Dotfiler::Cli::Program.start ARGV, package: MyBackup
```

This library provides ready made packages to synchronize setting for common applications.
Several of these packages work in a cross platform manner (your Sublime Settings will roam between your Windows, Linux and Mac OS machine).

You can always create custom packages as the one below to synchronize some set of files on *certain OSes*, *certain machines*, or *run custom scripts*.

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
