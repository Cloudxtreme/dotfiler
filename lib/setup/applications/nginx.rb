module Setup
  module Applications
    # Package for Nginx application.
    class NginxPackage < Setup::Tasks::Package
      package_name 'Nginx'
      platforms [:MACOS, :LINUX]
      restore_dir '/usr/local/etc'

      def steps
        yield file 'nginx'
      end
    end
  end # module Applications
end # module Setup
