module Setup
module Applications

class VimPackage < Setup::Package
  package_name 'Vim'

  def steps
    file '.gvimrc'
    file '.vimrc'
    file '.vim/autoload'
    file '.vim/settings'
    file '.vim/syntax'
    file '.vim/vimrc'
    file '.vim/vundles'
  end
end

end
end
