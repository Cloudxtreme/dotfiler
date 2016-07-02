class TmuxinatorPackage < PackageBase
  name 'Tmuxinator'
  platforms [:MACOS, :LINUX]

  def steps
    file '.tmuxinator'
  end
end
