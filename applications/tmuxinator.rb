class TmuxinatorPackage < Setup::Package
  name 'Tmuxinator'
  platforms [:MACOS, :LINUX]

  def steps
    file '.tmuxinator'
  end
end
