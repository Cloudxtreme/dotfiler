module Dotfiler
  module Applications
    # Package for Nginx application.
    class NginxPackage < Dotfiler::Tasks::Package
      package_name 'Nginx'
      platforms [:MACOS, :LINUX]
      restore_dir '/usr/local/etc'

      def steps
        yield file 'nginx'
      end
    end
  end
end
