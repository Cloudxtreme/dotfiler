require 'dotfiler/edits/ast'

module Dotfiler
  module Edits
    # @api private
    # Utilities which help with parsing ruby strings into an AST.
    module ParserUtils
      # Returns a parser which should be used to parse ruby files.
      # The parser is compatible with ruby 2.1 syntax.
      def parser
        require 'parser/ruby21'
        Parser::Ruby21.new Dotfiler::Edits::AST::Builder.new
      end

      # Creates a {::Parser::Source::Buffer} given ruby source code.
      # @param str [String] ruby source for which to create a {::Parser::Source::Buffer}.
      def buffer(str)
        Parser::Source::Buffer.new('path').tap { |buffer| buffer.source = str }
      end

      # Creates a {::Parser::AST::Node} given ruby source code.
      # @param str [String, Parser::Source::Buffer] ruby source for which to create a {::Parser::AST::Node}.
      def ast(str)
        str_buffer = str.is_a?(Parser::Source::Buffer) ? str : buffer(str)
        parser.parse str_buffer
      end
    end
  end
end
