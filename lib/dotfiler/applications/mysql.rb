module Dotfiler
  module Applications
    # Package for MySQL application.
    class MySQLPackage < Dotfiler::Tasks::Package
      package_name 'MySQL'
      platforms [:MACOS, :LINUX]
      restore_dir '/usr/local/etc'

      def steps
        yield file 'my.cnf'
        yield file 'my.cnf.d'
      end
    end
  end
end
