module Setup
  module Applications
    # Package for Byobu application.
    class ByobuPackage < Setup::Tasks::Package
      package_name 'Byobu'
      platforms [:MACOS, :LINUX]
      restore_dir '.byobu'

      def steps
        yield file 'profile.tmux'
      end
    end
  end # module Applications
end # module Setup
