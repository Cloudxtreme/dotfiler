module Setup
  module Applications
    class IntelliJPackage < Setup::Package
      package_name 'IntelliJ IDEA'

      def steps
        yield file '.IntelliJIdea15/config'
      end
    end
  end # module Applications
end # module Setup
