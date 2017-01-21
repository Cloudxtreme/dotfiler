module Setup
  module Applications
    # Package for Atom application.
    class AtomPackage < Setup::Tasks::Package
      package_name 'Atom'
      restore_dir '~/.atom'

      def steps
        yield file 'config.cson'
        yield file 'init.coffee'
        yield file 'keymap.cson'
        yield file 'snippets.cson'
        yield file 'styles.less'
      end
    end
  end # module Applications
end # module Setup
