require 'setup/edits/parser_utils'

require 'parser'

module Setup
  module Edits
    # @api private
    # Utilities which help with rewriting ruby code.
    module RewriterUtils
      include ParserUtils

      # Space indentation used by scripts.
      INDENTATION = 2

      def line_range(location)
        @source_rewriter.source_buffer.line_range location.line
      end

      def insert_above(location, str)
        indentation = location.column + INDENTATION
        str = str.split("\n").map { |line| indent_line line, indentation }.join("\n")
        @source_rewriter.insert_before_multi line_range(location), str + "\n"
      end

      def indent_line(line, indentation)
        line.empty? ? line : ' ' * indentation + line
      end

      def rewrite_str(str)
        str_buffer = buffer str
        str_ast = ast str_buffer
        rewrite str_buffer, str_ast
      end
    end # module RewriterUtils
  end # module Edits
end # module Setup
