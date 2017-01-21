module Setup
  module Applications
    # Package for Visual Studio Code application.
    class VsCodePackage < Setup::Tasks::Package
      package_name 'VsCode'
      under_windows { restore_dir '~/AppData/Roaming/Code/User' }
      under_macos   { restore_dir '~/Library/Application Support/Code/User' }

      def steps
        yield file 'settings.json'
        yield file 'snippets'
      end
    end
  end # module Applications
end # module Setup
