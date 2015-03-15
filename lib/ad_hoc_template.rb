require "ad_hoc_template/version"
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

    def self.split_into_tokens(str)
      tokens = []

      while m = TOKEN_PAT.match(str)
        tokens.push m.pre_match unless m.pre_match.empty?
        tokens.push m[0]
        str = m.post_match
      end

      tokens.push str unless str.empty?
      tokens
    end

    def self.parse(str)
      new(str).parse.tree
    end

    def initialize(str)
      @tokens = Parser.split_into_tokens(str)
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
  end

  module RecordReader
    SEPARATOR = /:\s*/o
    BLOCK_HEAD = /\A\/\/@/o
    EMPTY_LINE = /\A\r?\n\Z/o
    ITERATION_MARK = /\A#/o

    def self.remove_leading_empty_lines(lines)
      until lines.empty? or /\S/o.match(lines.first)
        lines.shift
      end
    end

    def self.strip_blank_lines(block)
      remove_leading_empty_lines(block)
      block.pop while not block.empty? and EMPTY_LINE.match(block.last)
    end

    def self.read_key_value_list(lines, record)
      while line = lines.shift and not EMPTY_LINE.match(line)
        key, val = line.chomp.split(SEPARATOR, 2)
        record[key] = val
      end

      record
    end

    def self.read_block(lines, record, block_head)
      block = []

      while line = lines.shift
        if m = BLOCK_HEAD.match(line)
          strip_blank_lines(block)
          record[block_head] = block.join
          return m.post_match.chomp
        end

        block.push(line)
      end

      strip_blank_lines(block)
      record[block_head] = block.join
    end

    def self.read_block_part(lines, record, block_head)
      until lines.empty? or not block_head
        block_head = read_block(lines, record, block_head)
      end
    end

    def self.read_iteration_block(lines, record, block_head)
      records = []

      while line = lines.shift
        if m = BLOCK_HEAD.match(line)
          record[block_head] = records
          return m.post_match.chomp
        elsif EMPTY_LINE.match(line)
          next
        else
          lines.unshift line
          records.push read_key_value_list(lines, {})
        end
      end

      record[block_head] = records
      nil
    end

    def self.read_iteration_block_part(lines, record, block_head)
      while not lines.empty? and block_head and ITERATION_MARK.match(block_head)
        block_head = read_iteration_block(lines, record, block_head)
      end

      block_head
    end

    def self.read_record(input)
      lines = input.each_line.to_a
      record = read_key_value_list(lines, {})
      remove_leading_empty_lines(lines)

      unless lines.empty?
        m = BLOCK_HEAD.match(lines.shift)
        block_head = read_iteration_block_part(lines, record, m.post_match.chomp)
        read_block_part(lines, record, block_head) if block_head
      end

      record
    end
  end

  class DefaultTagFormatter
    def find_function(tag_type)
      FUNCTION_TABLE[tag_type]||:default
    end

    def format(tag_type, var, record)
      self.send(find_function(tag_type), var, record)
    end

    def default(var, record)
      record[var]||"[#{var}]"
    end

    def html_encode(var ,record)
      HtmlElement.escape(record[var]||var)
    end

    FUNCTION_TABLE = {
      "=" => :default,
      "h" => :html_encode
    }
  end

  class Converter
    def self.convert(record_data, template, formatter=DefaultTagFormatter.new)
      tree = AdHocTemplate::Parser.parse(template)
      record = AdHocTemplate::RecordReader.read_record(record_data)
      AdHocTemplate::Converter.new(record, formatter).format(tree)
    end

    def initialize(record, formatter=DefaultTagFormatter.new)
      @record = record
      @formatter = formatter
    end

    def visit(tree)
      case tree
      when Parser::IterationTagNode
        format_iteration_tag(tree)
      when Parser::TagNode
        format_tag(tree)
      when Parser::Leaf
        tree.join
      else
        tree.map {|node| node.accept(self) }
      end
    end

    def format_iteration_tag(tag_node)
      sub_records = @record["#"+(tag_node.type||"".freeze)]||[@record]
      tag_node = Parser::TagNode.new.concat(tag_node.clone)

      sub_records.map do |record|
        if tag_node.contains_any_value_assigned_tag_node?(record)
          converter = AdHocTemplate::Converter.new(record, @formatter)
          tag_node.map {|leaf| leaf.accept(converter) }.join
        else
          "".freeze
        end
      end
    end

    def format_tag(tag_node)
      leafs = tag_node.map {|leaf| leaf.accept(self) }
      @formatter.format(tag_node.type, leafs.join.strip, @record)
    end

    def format(tree)
      tree.accept(self).join
    end
  end
end
