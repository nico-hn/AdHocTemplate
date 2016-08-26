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

    class TagType
      attr_reader :head, :tail, :token_pat
      @types = {}

      def self.[](tag_name)
        @types[tag_name]
      end

      def self.register(tag_name=:default, tag=["<%", "%>"], iteration_tag=["<%#", "#%>"])
        @types[tag_name] = new(tag, iteration_tag)
      end

      def initialize(tag, iteration_tag)
        assign_type(tag, iteration_tag)
        @token_pat = PseudoHiki.compile_token_pat(@head.keys, @tail.keys)
      end

      def assign_type(tag, iteration_tag)
        @head, @tail = {}, {}
        [
          [TagNode, tag],
          [IterationTagNode, iteration_tag]
        ].each do |node_type, head_tail|
          head, tail = head_tail
          @head[head] = node_type
          @tail[tail] = node_type
        end
      end

      register
    end

    HEAD, TAIL = {}, {}

    [[TagNode, "<%", "%>"],
     [IterationTagNode, "<%#", "#%>"]].each do |type, head, tail|
      HEAD[head] = type
      TAIL[tail] = type
    end

    TOKEN_PAT = PseudoHiki.compile_token_pat(HEAD.keys, TAIL.keys)

    def self.parse(str, tag_name=:default)
      new(str, TagType[tag_name]).parse.tree
    end

    def initialize(str, tag)
      @tag = tag
      str = remove_trailing_newline_of_iteration_tag_node_end_tag(str)
      @tokens = PseudoHiki.split_into_tokens(str, @tag.token_pat)
      super()
    end

    def parse
      while token = @tokens.shift
        next if @tag.tail[token] == current_node.class and self.pop
        next if @tag.head[token] and self.push @tag.head[token].new
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
