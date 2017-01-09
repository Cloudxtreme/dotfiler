module Setup
module Applications

class ByobuPackage < Setup::Package
  package_name 'Byobu'
  platforms [:MACOS, :LINUX]
  restore_dir '.byobu'

  def steps
    yield file 'profile.tmux'
  end
end

end
end
