module Setup
  module Applications
    class PowerShellPackage < Setup::Package
      package_name 'PowerShell'
      platforms [:WINDOWS]
      restore_dir '~/Documents/WindowsPowerShell'

      def steps
        yield file 'Microsoft.PowerShell_profile.ps1'
      end
    end
  end # module Applications
end # module Setup
