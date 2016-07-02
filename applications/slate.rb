class SlatePackage < Package
  name 'Slate'
  platforms [:MACOS, :LINUX]

  def steps
    file '.slate'
  end
end