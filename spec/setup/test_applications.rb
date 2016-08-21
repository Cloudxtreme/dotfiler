# TODO(drognanar): Prefix all packages files with test to prevent from moving actual dotfiles around.
require 'setup/package'

module Setup
module Test

# An app with no files to sync.
class AppPackage < Setup::Package
    package_name 'app'

    def steps
    end
end

# An app where the file is only present at the restore location.
class VimPackage < Setup::Package
    package_name 'vim'

    def steps
        file '.vimrc'
    end
end

# An app where the backup will overwrite files.
class CodePackage < Setup::Package
    package_name 'code'

    def steps
        file '.vscode'
    end
end

# An app where only some files exist on the machine.
# An app which only contains the file in the backup directory.
class BashPackage < Setup::Package
    package_name 'bash'

    def steps
        file '.bashrc'
        file '.bash_local'
    end
end

# An app where no files exist.
class GitPackage < Setup::Package
    package_name 'git'

    def steps
        file '.gitignore'
        file '.gitconfig'
    end
end

# An app where the both backup and restore have the same content.
class PythonPackage < Setup::Package
    package_name 'python'

    def steps
        file '.pythonrc'
    end
end

# An app where all files have been completely synced.
class RubocopPackage < Setup::Package
    package_name 'rubocop'

    def steps
        file '.rubocop'
    end
end

end
end
