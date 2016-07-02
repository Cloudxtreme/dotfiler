class IntelliJPackage < PackageBase
  name 'IntelliJ IDEA'

  def steps
    file '.IntelliJIdea15/config'
  end
end