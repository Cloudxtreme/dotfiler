require 'setup/edits/ast'

require 'parser/current'

module Setup
  module Edits
    module ParserUtils
      def parser
        Parser::CurrentRuby.new Setup::Edits::AST::Builder.new
      end

      def buffer(str)
        Parser::Source::Buffer.new('path').tap { |buffer| buffer.source = str }
      end

      def ast(str)
        str_buffer = str.is_a?(Parser::Source::Buffer) ? str : buffer(str)
        parser.parse str_buffer
      end
    end # module ParserUtils
  end # module Edits
end # module Setup
