module Setup
module Applications

class GitPackage < Setup::Package
  package_name 'Git'

  def steps
    yield file '.gitignore'
    under_windows { yield file('.gitconfig').save_as('_gitconfig(win)') }
    under_macos   { yield file('.gitconfig').save_as('_gitconfig(osx)') }
  end
end

end
end
