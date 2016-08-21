class IntelliJPackage < Setup::Package
  package_name 'IntelliJ IDEA'

  def steps
    file '.IntelliJIdea15/config'
  end
end