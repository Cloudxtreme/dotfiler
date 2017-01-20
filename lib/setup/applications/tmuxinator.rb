module Setup
  module Applications
    class TmuxinatorPackage < Setup::Package
      package_name 'Tmuxinator'
      platforms [:MACOS, :LINUX]

      def steps
        yield file '.tmuxinator'
      end
    end
  end # module Applications
end # module Setup
