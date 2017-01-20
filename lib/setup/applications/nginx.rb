module Setup
  module Applications
    class NginxPackage < Setup::Package
      package_name 'Nginx'
      platforms [:MACOS, :LINUX]
      restore_dir '/usr/local/etc'

      def steps
        yield file 'nginx'
      end
    end
  end # module Applications
end # module Setup
