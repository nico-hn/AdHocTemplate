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
  end

  module RecordReader
    SEPARATOR = /:\s*/o
    BLOCK_HEAD = /\A\/\/@/o
    ITERATION_HEAD = /\A\/\/@#/o
    EMPTY_LINE = /\A\r?\n\Z/o
    ITERATION_MARK = /\A#/o
    READERS_RE = {
      key_value: SEPARATOR,
      iteration: ITERATION_HEAD,
      block: BLOCK_HEAD,
      empty_line: EMPTY_LINE,
    }

    class ReaderState
      attr_accessor :current_block_label

      def initialize(config={}, stack=[])
        @stack = stack
        @configs = [config]
      end

      def push(reader)
        @stack.push reader
      end

      def pop
        @stack.pop unless @stack.length == 1
      end

      def setup_stack(line)
        @stack[-1].setup_stack(line)
      end

      def current_reader
        @stack[-1]
      end

      def read(line)
        @stack[-1].read(line)
      end

      def length
        @stack.length
      end

      def push_new_record
        new_record = {}
        @configs.push new_record
        new_record
      end

      def pop_current_record
        @configs.pop
      end

      def current_record
        @configs[-1]
      end

      def parsed_record
        @configs[0]
      end
    end

    class Reader
      def self.setup_reader(stack)
        readers = {}
        {
          base: BaseReader,
          key_value: KeyValueReader,
          block: BlockReader,
          iteration: IterationReader,
        }.each do |k, v|
          readers[k] = v.new(stack, readers)
        end
        stack.push readers[:base]
        readers
      end

      def self.read_record(lines)
        stack = ReaderState.new

        setup_reader(stack)

        lines = lines.each_line.to_a if lines.kind_of? String

        lines.each do |line|
          stack.setup_stack(line)
          stack.read(line)
        end

        if stack.current_reader.kind_of? BlockReader
          label = stack.current_block_label
          stack.current_record[label].sub!(/(#{$/})+\Z/, $/)
        end

        stack.parsed_record
      end

      def initialize(stack, readers)
        @stack = stack
        @readers = readers
      end

      def pop_stack
        @stack.pop
      end

      private

      def last_block_value
        label = @stack.current_block_label
        @stack.current_record[label]
      end

      def push_reader_if_match(line, readers)
        readers.each do |reader|
          return @stack.push(@readers[reader]) if READERS_RE[reader] === line
        end
      end

      def setup_new_block(line, initial_value)
        label = line.sub(BLOCK_HEAD, "").chomp
        @stack.current_record[label] ||= initial_value
        @stack.current_block_label = label
      end
    end


    class BaseReader < Reader
      def setup_stack(line)
        push_reader_if_match(line, [:iteration, :block, :key_value])
      end

      def read(line)
      end
    end

    class KeyValueReader < Reader
      def setup_stack(line)
        case line
        when EMPTY_LINE, ITERATION_HEAD, BLOCK_HEAD
          pop_stack
        end
        push_reader_if_match(line, [:iteration, :block])
      end

      def read(line)
        key, value = line.split(SEPARATOR, 2)
        @stack.current_record[key] = value.chomp
      end
    end

    class BlockReader < Reader
      def setup_stack(line)
        case line
        when ITERATION_HEAD, BLOCK_HEAD
          remove_trailing_newlines
          pop_stack
        end
        push_reader_if_match(line, [:iteration, :block])
      end

      def read(line)
        label = @stack.current_block_label
        case line
        when BLOCK_HEAD
          setup_new_block(line, String.new)
        when EMPTY_LINE
          unless @stack.current_record[label].empty?
            @stack.current_record[label] << line
          end
        else
          @stack.current_record[label] << line
        end
      end

      private

      def remove_trailing_newlines
        last_block_value.sub!(/(#{$/})+\Z/, $/)
      end
    end

    class IterationReader < Reader
      def setup_stack(line)
        case line
        when ITERATION_HEAD
          @stack.pop_current_record
        when BLOCK_HEAD
          @stack.pop_current_record
          pop_stack
          @stack.push @readers[:block]
        when SEPARATOR
          @stack.pop_current_record
          last_block_value.push @stack.push_new_record
          @stack.push @readers[:key_value]
        end
      end

      def read(line)
        case line
        when ITERATION_HEAD
          setup_new_block(line, [])
          @stack.push_new_record
        end
      end
    end

    def self.read_record(input)
      Reader.read_record(input)
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
      sub_records = @record[tag_node.type]||[@record]
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
