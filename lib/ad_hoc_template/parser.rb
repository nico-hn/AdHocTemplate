#!/usr/bin/env ruby

require "pseudohiki/inlineparser"
require "htmlelement"

module AdHocTemplate
  LINE_END_RE = /(?:\r?\n|\r)/
  LINE_END_STR = '(?:\r?\n|\r)'

  class Parser < TreeStack
    class TagNode < Parser::Node
      attr_reader :type

      def push(node=TreeStack::Node.new)
        node[0] = assign_type(node[0]) if self.empty?
        super
      end

      def assign_type(first_leaf)
        if not first_leaf.kind_of? String or /\A\s/ =~ first_leaf
          return first_leaf.sub(/\A#{LINE_END_STR}/, "")
        end
        @type, first_leaf_content = split_by_newline_or_spaces(first_leaf)
        @type = '#'.freeze + @type if kind_of? IterationTagNode
        first_leaf_content||""
      end

      def split_by_newline_or_spaces(first_leaf)
        sep = /\A\S*#{LINE_END_STR}/ =~ first_leaf ? LINE_END_RE : /\s+/
        first_leaf.split(sep, 2)
      end
      private :assign_type, :split_by_newline_or_spaces

      def contains_any_value_assigned_tag_node?(record)
        self.select {|n| n.kind_of?(TagNode) }.each do |node|
          if node.kind_of? IterationTagNode
            return true if any_value_assigned_to_iteration_tag?(node, record)
          else
            val = record[node.join.strip]
            return true if val and not val.empty?
          end
        end
        false
      end

      private

      def empty_sub_records?(record, node)
        sub_records = record[node.type]
        return true if sub_records.nil? or sub_records.empty?
        sub_records.each do |rec|
          return false if rec.values.find {|val| val and not val.empty? }
        end
      end

      def any_value_assigned_to_iteration_tag?(tag_node, record)
        if tag_node.type
          not empty_sub_records?(record, tag_node)
        elsif tag_node.kind_of? FallbackTagNode
          false
        else
          tag_node.contains_any_value_assigned_tag_node?(record)
        end
      end
    end

    class IterationTagNode < TagNode; end
    class FallbackTagNode < TagNode; end
    class Leaf < Parser::Leaf; end

    class TagType
      attr_reader :head, :tail, :token_pat, :remove_iteration_indent
      attr_reader :head_of, :tail_of
      @types = {}

      def self.[](tag_name)
        @types[tag_name]
      end

      def self.register(tag_name=:default, tag=["<%", "%>"], iteration_tag=["<%#", "#%>"],
                        fallback_tag=["<%*", "*%>"], remove_iteration_indent=false)
        @types[tag_name] = new(tag, iteration_tag, fallback_tag, remove_iteration_indent)
      end

      def initialize(tag, iteration_tag, fallback_tag, remove_iteration_indent)
        assign_type(tag, iteration_tag, fallback_tag)
        @token_pat = PseudoHiki.compile_token_pat(@head.keys, @tail.keys)
        @remove_iteration_indent = remove_iteration_indent
      end

      def assign_type(tag, iteration_tag, fallback_tag)
        @head, @tail, @head_of, @tail_of = {}, {}, {}, {}
        [
          [TagNode, tag],
          [IterationTagNode, iteration_tag],
          [FallbackTagNode, fallback_tag]
        ].each do |node_type, head_tail|
          head, tail = head_tail
          @head[head] = node_type
          @tail[tail] = node_type
          @head_of[node_type] = head
          @tail_of[node_type] = tail
        end
      end

      register
      register(:square_brackets, ["[[", "]]"], ["[[#", "#]]"], ["[[*", "*]]"])
      register(:curly_brackets, ["{{", "}}"], ["{{#", "#}}"], ["{{*", "*}}"])
      register(:xml_like1, ["<!--%", "%-->"], ["<iterate>", "</iterate>"], ["<fallback>", "</fallback>"], true)
      register(:xml_like2, ["<fill>", "</fill>"], ["<iterate>", "</iterate>"], ["<fallback>", "</fallback>"], true)
      register(:xml_comment_like, ["<!--%", "%-->"], ["<!--%iterate%-->", "<!--%/iterate%-->"], ["<!--%fallback%-->", "<!--%/fallback%-->"], true)
    end

    class UserDefinedTagTypeConfigError < StandardError; end

    def self.parse(str, tag_name=:default)
      if TagType[tag_name].remove_iteration_indent
        str = remove_indent_before_iteration_tags(str, TagType[tag_name])
        str = remove_indent_before_fallback_tags(str, TagType[tag_name])
      end
      new(str, TagType[tag_name]).parse.tree
    end

    def self.remove_indent_before_iteration_tags(template_source, tag_type)
      start_tag, end_tag = [
        tag_type.head_of[IterationTagNode],
        tag_type.tail_of[IterationTagNode],
      ].map {|tag| Regexp.escape(tag) }
      template_source.gsub(/^([ \t]+#{start_tag}\S*#{LINE_END_STR})/) {|s| s.lstrip }
        .gsub(/^([ \t]+#{end_tag}#{LINE_END_STR})/) {|s| s.lstrip }
    end

    def self.remove_indent_before_fallback_tags(template_source, tag_type)
      tag_re_str = [
        tag_type.head_of[FallbackTagNode],
        tag_type.tail_of[FallbackTagNode],
      ].map {|tag| Regexp.escape(tag) }.join('|')
      template_source.gsub(/^([ \t]+(?:#{tag_re_str})#{LINE_END_STR})/) {|s| s.lstrip }
    end

    def self.register_user_defined_tag_type(config_source)
      config = YAML.load(config_source)
      %w(tag_name tag iteration_tag fallback_tag).each do |item|
        config[item] || raise(UserDefinedTagTypeConfigError,
                              "\"#{item}\" should be defined.")
      end
      TagType.register(registered_tag_name = config["tag_name"].to_sym,
                       config["tag"],
                       config["iteration_tag"],
                       config["fallback_tag"],
                       config["remove_indent"] || false)
      registered_tag_name
    end

    def initialize(source, tag)
      @tag = tag
      node_types = [IterationTagNode, FallbackTagNode]
      source = remove_trailing_newline_of_end_tags(node_types,  source)
      @tokens = PseudoHiki.split_into_tokens(source, @tag.token_pat)
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

    def remove_trailing_newline_of(end_tag, str)
      str.gsub(/#{Regexp.escape(end_tag)}#{LINE_END_STR}/, end_tag)
    end

    def remove_trailing_newline_of_end_tags(node_types, source)
      node_types.inject(source) do |s, node_type|
        remove_trailing_newline_of(@tag.tail_of[node_type], s)
      end
    end
  end
end
