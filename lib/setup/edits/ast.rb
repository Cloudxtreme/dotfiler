require 'parser'

module Setup

module AST

class Builder < Parser::Builders::Default
  def n(type, children, source_map)
    case type
    when :def then DefNode.new type, children, location: source_map
    when :class then DefNode.new type, children, location: source_map
    else Node.new type, children, location: source_map
    end
  end
end

class Node < Parser::AST::Node
  def initialize(type, children = [], properties = {})
    super
  end

  def children_with(type)
    children.select { |child| child.is_a? Node and child.type == type }
  end

  def child(type)
    children_with(type)[0] || NOT_FOUND
  end
end

class DefNode < Node
  attr_reader :body

  def initialize(type, children = [], properties = {})
    body_node = children[2]
    if body_node.nil? then @body = []
    elsif body_node.type == :begin then @body = body_node.children
    else @body = [body_node]
    end
    super
  end
end

NOT_FOUND = Node.new :not_found, [], {}

end

end