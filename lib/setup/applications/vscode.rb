module Setup
module Applications

class VsCodePackage < Setup::Package
  package_name 'VsCode'
  under_windows { restore_dir '~/AppData/Roaming/Code/User' }
  under_macos   { restore_dir '~/Library/Application Support/Code/User' }

  def steps
    yield file 'settings.json'
    yield file 'snippets'
  end
end

end
end
