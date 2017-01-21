module Setup
  module Applications
    # Package for Tmuxinator application.
    class TmuxinatorPackage < Setup::Tasks::Package
      package_name 'Tmuxinator'
      platforms [:MACOS, :LINUX]

      def steps
        yield file '.tmuxinator'
      end
    end
  end # module Applications
end # module Setup
