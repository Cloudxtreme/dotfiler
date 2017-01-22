module Dotfiler
  module Applications
    # Package for Slate application.
    class SlatePackage < Dotfiler::Tasks::Package
      package_name 'Slate'
      platforms [:MACOS, :LINUX]

      def steps
        yield file '.slate'
      end
    end
  end
end
