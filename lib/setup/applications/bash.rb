module Setup
  module Applications
    # Package for Bash application.
    class BashPackage < Setup::Tasks::Package
      package_name 'Bash'

      def steps
        yield file '.bashrc'
        yield file '.bash_profile'
        yield file '.bash_functions'
        yield file '.bash_aliases'
        under_macos { yield file('.bash_local').save_as('_bash_local(osx)') }
      end
    end
  end # module Applications
end # module Setup
