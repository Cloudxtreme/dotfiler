module Setup
  module Applications
    # Package for Slate application.
    class SlatePackage < Setup::Tasks::Package
      package_name 'Slate'
      platforms [:MACOS, :LINUX]

      def steps
        yield file '.slate'
      end
    end
  end # module Applications
end # module Setup
