module Dotfiler
  module Applications
    # Package for Fish application.
    class FishPackage < Dotfiler::Tasks::Package
      package_name 'Fish'
      platforms [:MACOS, :LINUX]
      restore_dir '.config/fish'

      def steps
        yield file 'config.fish'
        yield file 'functions'
      end
    end
  end
end
