require 'dotfiler/tasks/package'

module Dotfiler
  module Test
    # An app with no files to sync.
    class AppPackage < Dotfiler::Tasks::Package
      package_name 'app'

      def steps; end
    end

    # An app where the file is only present at the restore location.
    class VimPackage < Dotfiler::Tasks::Package
      package_name 'vim'

      def steps
        yield file '.test_vimrc'
      end
    end

    # An app where the backup will overwrite files.
    class CodePackage < Dotfiler::Tasks::Package
      package_name 'code'

      def steps
        yield file '.test_vscode'
      end
    end

    # An app where only some files exist on the machine.
    # An app which only contains the file in the backup directory.
    class BashPackage < Dotfiler::Tasks::Package
      package_name 'bash'

      def steps
        yield file '.test_bashrc'
        yield file '.test_bash_local'
      end
    end

    # An app where no files exist.
    class GitPackage < Dotfiler::Tasks::Package
      package_name 'git'

      def steps
        yield file '.test_gitignore'
        yield file '.test_gitconfig'
      end
    end

    # An app where the both backup and restore have the same content.
    class PythonPackage < Dotfiler::Tasks::Package
      package_name 'python'

      def steps
        yield file '.test_pythonrc'
      end
    end

    # An app where all files have been completely synced.
    class RubocopPackage < Dotfiler::Tasks::Package
      package_name 'rubocop'

      def steps
        yield file '.test_rubocop'
      end
    end
  end
end
