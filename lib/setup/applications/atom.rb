module Setup
module Applications

class AtomPackage < Setup::Package
  package_name 'Atom'
  restore_to '~/.atom'

  def steps
    yield file 'config.cson'
    yield file 'init.coffee'
    yield file 'keymap.cson'
    yield file 'snippets.cson'
    yield file 'styles.less'
  end
end

end
end
