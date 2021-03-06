module Dotfiler
  module Applications
    # Package for Vim application.
    class VimPackage < Dotfiler::Tasks::Package
      package_name 'Vim'

      def steps
        yield file '.gvimrc'
        yield file '.vimrc'
        yield file '.vim/autoload'
        yield file '.vim/settings'
        yield file '.vim/syntax'
        yield file '.vim/vimrc'
        yield file '.vim/vundles'
      end
    end
  end
end
