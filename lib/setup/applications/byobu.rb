class ByobuPackage < Setup::Package
  package_name 'Byobu'
  platforms [:MACOS, :LINUX]
  restore_to '.byobu'

  def steps
    file 'profile.tmux'
  end
end
