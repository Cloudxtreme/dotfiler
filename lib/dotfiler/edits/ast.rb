require 'parser'

module Dotfiler
  module Edits
    # @api private
    module AST
      # An AST builder that specializes the def and class nodes.
      # This allows to get class definitions/method instructions in a consistent manner.
      class Builder < Parser::Builders::Default
        def n(type, children, source_map)
          case type
          when :def then DefNode.new type, children, location: source_map
          when :class then DefNode.new type, children, location: source_map
          else Parser::AST::Node.new type, children, location: source_map
          end
        end
      end

      class DefNode < Parser::AST::Node
        attr_reader :body

        def initialize(type, children = [], properties = {})
          body_node = children[2]
          @body = if body_node.nil? then []
                  elsif body_node.type == :begin then body_node.children
                  else [body_node]
                  end
          super
        end
      end
    end
  end
end
