module Setup
module Applications

class SublimeTextPackage < Setup::Package
  package_name 'Sublime Text 3'
  platforms [:MACOS, :WINDOWS]
  under_macos   { restore_to '~/Library/Application Support/Sublime Text 3' }
  under_windows { restore_to '~/AppData/Roaming/Sublime Text 3' }

  def steps
    under_macos   { yield file 'Packages/User/Default (OSX).sublime-keymap' }
    under_windows { yield file 'Packages/User/Default (Windows).sublime-keymap' }
    yield file 'Packages/User/Preferences.sublime-settings'
    yield file 'Packages/User/Package Control.sublime-settings'
  end
end

end
end
