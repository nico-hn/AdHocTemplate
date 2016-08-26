#!/usr/bin/env ruby

require "pseudohiki/inlineparser"
require "htmlelement"

module AdHocTemplate
  class Parser < TreeStack
    class TagNode < Parser::Node
      attr_reader :type

      def push(node=TreeStack::Node.new)
        node[0] = assign_type(node[0]) if self.empty?
        super
      end

      def assign_type(first_leaf)
        return first_leaf unless first_leaf.kind_of? String and /^\S/o.match(first_leaf)
        @type, first_leaf_content = first_leaf.split(/\s+/o, 2)
        @type = '#'.freeze + @type if kind_of? IterationTagNode
        first_leaf_content||""
      end
      private :assign_type

      def contains_any_value_assigned_tag_node?(record)
        self.select {|n| n.kind_of?(TagNode) }.each do |node|
          val = record[node.join.strip]
          return true if val and not val.empty?
        end
        false
      end
    end

    class IterationTagNode < TagNode; end
    class Leaf < Parser::Leaf; end

    HEAD, TAIL = {}, {}

    [[TagNode, "<%", "%>"],
     [IterationTagNode, "<%#", "#%>"]].each do |type, head, tail|
      HEAD[head] = type
      TAIL[tail] = type
    end

    TOKEN_PAT = PseudoHiki.compile_token_pat(HEAD.keys, TAIL.keys)

    def self.parse(str)
      new(str).parse.tree
    end

    def initialize(str)
      str = remove_trailing_newline_of_iteration_tag_node_end_tag(str)
      @tokens = PseudoHiki.split_into_tokens(str, TOKEN_PAT)
      super()
    end

    def parse
      while token = @tokens.shift
        next if TAIL[token] == current_node.class and self.pop
        next if HEAD[token] and self.push HEAD[token].new
        self.push Leaf.create(token)
      end

      self
    end

    private

    def remove_trailing_newline_of_iteration_tag_node_end_tag(str)
      str.gsub(/#%>\r?\n/, '#%>')
    end
  end
end
