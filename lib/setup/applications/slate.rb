module Setup
  module Applications
    class SlatePackage < Setup::Package
      package_name 'Slate'
      platforms [:MACOS, :LINUX]

      def steps
        yield file '.slate'
      end
    end
  end # module Applications
end # module Setup
