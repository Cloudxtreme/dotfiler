class GitPackage < Setup::Package
  package_name 'Git'

  def steps
    file '.gitignore'
    under_windows { file('.gitconfig').save_as('_gitconfig(win)') }
    under_macos   { file('.gitconfig').save_as('_gitconfig(osx)') }
  end
end