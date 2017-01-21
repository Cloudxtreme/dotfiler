module Setup
  module Applications
    # Package for MySQL application.
    class MySQLPackage < Setup::Tasks::Package
      package_name 'MySQL'
      platforms [:MACOS, :LINUX]
      restore_dir '/usr/local/etc'

      def steps
        yield file 'my.cnf'
        yield file 'my.cnf.d'
      end
    end
  end # module Applications
end # module Setup
