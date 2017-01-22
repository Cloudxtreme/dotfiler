module Dotfiler
  module Applications
    # Package for IntelliJ idea application.
    class IntelliJPackage < Dotfiler::Tasks::Package
      package_name 'IntelliJ IDEA'

      def steps
        yield file '.IntelliJIdea15/config'
      end
    end
  end
end
