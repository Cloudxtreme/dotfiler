module Setup
module Applications

class TmuxinatorPackage < Setup::Package
  package_name 'Tmuxinator'
  platforms [:MACOS, :LINUX]

  def steps
    file '.tmuxinator'
  end
end

end
end