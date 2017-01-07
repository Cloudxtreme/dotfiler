module Setup
module Applications

class BashPackage < Setup::Package
  package_name 'Bash'

  def steps
    yield file '.bashrc'
    yield file '.bash_profile'
    yield file '.bash_functions'
    yield file '.bash_aliases'
    under_macos { yield file('.bash_local').save_as('_bash_local(osx)') }
  end
end

end
end
