class String # rubocop:disable Documentation
  # Copyright (c) 2005-2017 David Heinemeier Hansson
  # Using MIT LICENSE
  # Based on rails activesupport method.
  # @see https://github.com/rails/rails/blob/master/activesupport/lib/active_support/core_ext/string/strip.rb
  def strip_heredoc
    gsub(/^#{scan(/^[ \t]*(?=\S)/).min}/, ''.freeze)
  end
end
