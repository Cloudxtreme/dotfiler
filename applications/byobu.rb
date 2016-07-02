class ByobuPackage < Package
  name 'Byobu'
  platforms [:MACOS, :LINUX]
  restore_to '.byobu'

  def steps
    file 'profile.tmux'
  end
end
