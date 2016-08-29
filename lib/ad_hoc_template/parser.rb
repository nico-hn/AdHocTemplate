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
        if not first_leaf.kind_of? String or /\A\s/ =~ first_leaf
          return first_leaf.sub(/\A\r?\n/, "")
        end
        @type, first_leaf_content = split_by_newline_or_spaces(first_leaf)
        @type = '#'.freeze + @type if kind_of? IterationTagNode
        first_leaf_content||""
      end

      def split_by_newline_or_spaces(first_leaf)
        sep = /\A\S*\r?\n/ =~ first_leaf ? /\r?\n/ : /\s+/
        first_leaf.split(sep, 2)
      end
      private :assign_type, :split_by_newline_or_spaces

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
      attr_reader :iteration_end_tag
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
        _, @iteration_end_tag = iteration_tag
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
      register(:square_brackets, ["[[", "]]"], ["[[#", "#]]"])
      register(:curly_brackets, ["{{", "}}"], ["{{#", "#}}"])
      register(:xml_like1, ["<!--%", "%-->"], ["<iterate>", "</iterate>"])
      register(:xml_like2, ["<fill>", "</fill>"], ["<iterate>", "</iterate>"])
    end

    def self.parse(str, tag_name=:default)
      new(str, TagType[tag_name]).parse.tree
    end

    def initialize(str, tag)
      @tag = tag
      str = remove_trailing_newline_of_iteration_end_tag(str, @tag.iteration_end_tag)
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

    def remove_trailing_newline_of_iteration_end_tag(str, iteration_end_tag)
      str.gsub(/#{Regexp.escape(iteration_end_tag)}\r?\n/, iteration_end_tag)
    end
  end
end
