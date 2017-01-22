class String
  # (see https://github.com/rails/rails/blob/master/activesupport/lib/active_support/core_ext/string/strip.rb)
  def strip_heredoc
    gsub(/^#{scan(/^[ \t]*(?=\S)/).min}/, "".freeze)
  end
end
