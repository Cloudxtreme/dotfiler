module Setup
module Applications

class VsCodePackage < Setup::Package
  package_name 'VsCode'
  under_windows { restore_to '~/AppData/Roaming/Code/User' }
  under_macos   { restore_to '~/Library/Application Support/Code/User' }

  def steps
    file 'settings.json'
    file 'snippets'
  end
end

end
end
