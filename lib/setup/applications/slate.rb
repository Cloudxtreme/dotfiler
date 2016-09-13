module Setup
module Applications

class SlatePackage < Setup::Package
  package_name 'Slate'
  platforms [:MACOS, :LINUX]

  def steps
    file '.slate'
  end
end

end
end