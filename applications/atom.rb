class AtomPackage < PackageBase
  name 'Atom'
  restore_to '~/.atom'

  def steps
    file 'config.cson'
    file 'init.coffee'
    file 'keymap.cson'
    file 'snippets.cson'
    file 'styles.less'
  end
end