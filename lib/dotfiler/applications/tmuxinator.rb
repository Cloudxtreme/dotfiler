module Dotfiler
  module Applications
    # Package for Tmuxinator application.
    class TmuxinatorPackage < Dotfiler::Tasks::Package
      package_name 'Tmuxinator'
      platforms [:MACOS, :LINUX]

      def steps
        yield file '.tmuxinator'
      end
    end
  end
end
