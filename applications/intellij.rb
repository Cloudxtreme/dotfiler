class IntelliJPackage < Setup::Package
  name 'IntelliJ IDEA'

  def steps
    file '.IntelliJIdea15/config'
  end
end