module Setup
module Applications

class BashPackage < Setup::Package
  package_name 'Bash'

  def steps
    file '.bashrc'
    file '.bash_profile'
    file '.bash_functions'
    file '.bash_aliases'
    under_macos { file('.bash_local').save_as('_bash_local(osx)') }
  end
end

end
end
