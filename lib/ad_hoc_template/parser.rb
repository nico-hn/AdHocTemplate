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
          if node.kind_of? IterationTagNode
            sub_records = record[node.type]
            return true unless sub_records.nil? or sub_records.empty?
          else
            val = record[node.join.strip]
            return true if val and not val.empty?
          end
        end
        false
      end
    end

    class IterationTagNode < TagNode; end
    class Leaf < Parser::Leaf; end

    class TagType
      attr_reader :head, :tail, :token_pat, :remove_iteration_indent
      attr_reader :iteration_start, :iteration_end
      @types = {}

      def self.[](tag_name)
        @types[tag_name]
      end

      def self.register(tag_name=:default, tag=["<%", "%>"], iteration_tag=["<%#", "#%>"],
                        remove_iteration_indent=false)
        @types[tag_name] = new(tag, iteration_tag, remove_iteration_indent)
      end

      def initialize(tag, iteration_tag, remove_iteration_indent)
        assign_type(tag, iteration_tag)
        @token_pat = PseudoHiki.compile_token_pat(@head.keys, @tail.keys)
        @remove_iteration_indent = remove_iteration_indent
      end

      def assign_type(tag, iteration_tag)
        @iteration_start, @iteration_end = iteration_tag
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
      register(:xml_like1, ["<!--%", "%-->"], ["<iterate>", "</iterate>"], true)
      register(:xml_like2, ["<fill>", "</fill>"], ["<iterate>", "</iterate>"], true)
      register(:xml_comment_like, ["<!--%", "%-->"], ["<!--%iterate%-->", "<!--%/iterate%-->"], true)
    end

    def self.parse(str, tag_name=:default)
      if TagType[tag_name].remove_iteration_indent
        str = remove_indent_before_iteration_tags(str, TagType[tag_name])
      end
      new(str, TagType[tag_name]).parse.tree
    end

    def self.remove_indent_before_iteration_tags(template_source, tag_type)
      [
        tag_type.iteration_start,
        tag_type.iteration_end
      ].inject(template_source) do |s, tag|
        s.gsub(/^([ \t]+#{Regexp.escape(tag)}\r?\n)/) { $1.lstrip }
      end
    end

    def initialize(str, tag)
      @tag = tag
      str = remove_trailing_newline_of_iteration_end_tag(str, @tag.iteration_end)
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
