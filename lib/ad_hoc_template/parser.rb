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
        first_leaf = node[0]
        node[0] = assign_value_to_type(first_leaf) if empty? and first_leaf
        super
      end

      def contains_any_value_assigned_tag_node?(record)
        each_tag_node do |node|
          return true if node.contains_any_value_assigned_tag_node?(record)
        end
      end

      def contains_any_value_tag?
        each_tag_node {|node| return true if node.contains_any_value_tag? }
      end

      def inner_iteration_tag_labels
        names = []
        each_tag_node do |node|
          next unless node.kind_of? IterationTagNode
          names.push node.type if node.type
          if inner_names = node.inner_iteration_tag_labels
            names.concat inner_names
          end
        end

        names unless names.empty?
      end

      private

      def each_tag_node
        select {|n| n.kind_of?(TagNode) }.each {|node| yield node }
        false
      end

      def assign_value_to_type(first_leaf)
        if first_leaf.kind_of? String and /\A\s/ =~ first_leaf
          return first_leaf.sub(/\A#{LINE_END_STR}/, "")
        end
        @type, first_leaf_content = split_by_newline_or_spaces(first_leaf)
        first_leaf_content||""
      end

      def split_by_newline_or_spaces(first_leaf)
        sep = /\A\S*#{LINE_END_STR}/ =~ first_leaf ? LINE_END_RE : /\s+/
        first_leaf.split(sep, 2)
      end
    end

    class IterationTagNode < TagNode
      def assign_value_to_type(first_leaf)
        return first_leaf unless first_leaf.kind_of? String

        if /\A[^\s:]*:\s/ =~ first_leaf
          @type, remaining_part = first_leaf.split(/:(?:#{LINE_END_STR}|\s)/, 2)
          @type = @type.empty? ? nil : '#'.freeze + @type
          return remaining_part
        end

        first_leaf.sub(/\A#{LINE_END_STR}/, '')
      end

      def contains_any_value_assigned_tag_node?(record)
        return (not empty_sub_records?(record, self)) if type
        each_tag_node do |node|
          return true if node.contains_any_value_assigned_tag_node?(record)
        end
      end

      private

      def empty_sub_records?(record, node)
        sub_records = record[node.type]
        return true if sub_records.nil? or sub_records.empty?
        sub_records.each do |rec|
          return false if rec.values.find {|val| val and not val.empty? }
        end
      end
    end

    class FallbackTagNode < TagNode
      def assign_value_to_type(first_leaf)
        return first_leaf unless first_leaf.kind_of? String
        first_leaf.sub(/\A#{LINE_END_STR}/, '')
      end

      def contains_any_value_assigned_tag_node?(record)
        false
      end
    end

    class ValueNode < TagNode
      def contains_any_value_assigned_tag_node?(record)
        val = record[self.join.strip]
        val and not val.empty?
      end

      def contains_any_value_tag?
        true
      end
    end

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
        node_tag_pairs = [
          [ValueNode, *tag],
          [IterationTagNode, *iteration_tag],
          [FallbackTagNode, *fallback_tag]
        ]

        @head, @tail, @head_of, @tail_of = PseudoHiki.associate_nodes_with_tags(node_tag_pairs)
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
      str = remove_indents_and_newlines_if_necessary(str, tag_name)
      new(str, TagType[tag_name]).parse.tree
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

    def self.remove_indents_and_newlines_if_necessary(str, tag_name)
      node_types = [IterationTagNode, FallbackTagNode]
      tag_type = TagType[tag_name]
      if TagType[tag_name].remove_iteration_indent
        str = remove_indent_before_iteration_tags(str, tag_type)
        str = remove_indent_before_fallback_tags(str, tag_type)
      end
      remove_trailing_newline_of_end_tags(node_types, str, tag_type)
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

    def self.remove_trailing_newline_of_end_tags(node_types, source, tag_type)
      node_types.inject(source) do |s, node_type|
        end_tag = tag_type.tail_of[node_type]
        s.gsub(/#{Regexp.escape(end_tag)}#{LINE_END_STR}/, end_tag)
      end
    end

    private_class_method(:remove_indents_and_newlines_if_necessary,
                         :remove_indent_before_iteration_tags,
                         :remove_indent_before_fallback_tags,
                         :remove_trailing_newline_of_end_tags)

    def initialize(source, tag)
      @tag = tag
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
  end
end
