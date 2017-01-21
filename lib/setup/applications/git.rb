module Setup
  module Applications
    # Package for Git application.
    class GitPackage < Setup::Tasks::Package
      package_name 'Git'

      def steps
        yield file '.gitignore'
        under_windows { yield file('.gitconfig').save_as('_gitconfig(win)') }
        under_macos   { yield file('.gitconfig').save_as('_gitconfig(osx)') }
      end
    end
  end # module Applications
end # module Setup
