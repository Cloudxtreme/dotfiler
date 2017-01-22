module Dotfiler
  module Applications
    # Package for Git application.
    class GitPackage < Dotfiler::Tasks::Package
      package_name 'Git'

      def steps
        yield file '.gitignore'

        # Save .gitconfig separately since it includes editor and mergetools which can be OS specific.
        under_windows { yield file('.gitconfig').save_as('_gitconfig(windows)') }
        under_macos   { yield file('.gitconfig').save_as('_gitconfig(osx)') }
        under_linux   { yield file('.gitconfig').save_as('_gitconfig(linux)') }
      end
    end
  end
end
