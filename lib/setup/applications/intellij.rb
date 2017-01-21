module Setup
  module Applications
    # Package for IntelliJ idea application.
    class IntelliJPackage < Setup::Tasks::Package
      package_name 'IntelliJ IDEA'

      def steps
        yield file '.IntelliJIdea15/config'
      end
    end
  end # module Applications
end # module Setup
