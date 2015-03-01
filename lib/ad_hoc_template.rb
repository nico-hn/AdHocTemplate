require "ad_hoc_template/version"
require "pseudohiki/inlineparser"

module AdHocTemplate
  class Parser < TreeStack
    class TagNode < Parser::Node; end
    class IterationTagNode < Parser::Node; end
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

    class TagNode
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
    end
  end

  module ConfigurationReader
    SEPARATOR = /:\s*/o
    BLOCK_HEAD = /^\/\/@/o
    EMPTY_LINE = /^\r?\n/o
    ITERATION_MARK = /^#/o

    def self.remove_leading_empty_lines(lines)
      until lines.empty? or /\S/o.match(lines.first)
        lines.shift
      end
    end

    def self.read_header_part(lines, config)
      while line = lines.shift and not EMPTY_LINE.match(line)
        key, val = line.chomp.split(SEPARATOR, 2)
        config[key] = val
      end
    end

    def self.read_block(lines, config, block_head)
      block = []
      while line = lines.shift
        if m = BLOCK_HEAD.match(line)
          remove_leading_empty_lines(block)
          block.pop while not block.empty? and EMPTY_LINE.match(block.last)
          config[block_head] = block.join
          return m.post_match.chomp
        end

        block.push(line)
      end
      remove_leading_empty_lines(block)
      block.pop while not block.empty? and EMPTY_LINE.match(block.last)
      config[block_head] = block.join
    end

    def self.read_block_part(lines, config, block_head)
      until lines.empty? or not block_head
        block_head = read_block(lines, config, block_head)
      end
    end

    def self.read_iteration_block(lines, config, block_head)
      configs = []
      while line = lines.shift
        if m = BLOCK_HEAD.match(line)
          config[block_head] = configs
          return m.post_match.chomp
        elsif EMPTY_LINE.match(line)
          next
        else
          sub_config = {}
          lines.unshift line
          read_header_part(lines, sub_config)
          configs.push sub_config
        end
      end
      config[block_head] = configs
      nil
    end

    def self.read_iteration_block_part(lines, config, block_head)
      while not lines.empty? and block_head and ITERATION_MARK.match(block_head)
        block_head = read_iteration_block(lines, config, block_head)
      end
      block_head
    end

    def self.read_config(input)
      lines = input.each_line.to_a
      config = {}
      read_header_part(lines, config)
      remove_leading_empty_lines(lines)
      unless lines.empty?
        m = BLOCK_HEAD.match(lines.shift)
        read_block_part(lines, config, m.post_match.chomp)
      end
      config
    end
  end

  class DefaultTagFormatter
    def find_function(tag_type)
      @@function_table[tag_type]||:default
    end

    def format(tag_type, var, config)
      self.send(find_function(tag_type), var, config)
    end

    def default(var, config)
      config[var]||"[#{var}]"
    end

    @@function_table = {
      "=" => :default
    }
  end

  class Converter
    def self.convert(config_data, template, formatter=DefaultTagFormatter.new)
      tree = AdHocTemplate::Parser.parse(template)
      config = AdHocTemplate::ConfigurationReader.read_config(config_data)
      AdHocTemplate::Converter.new(config, formatter).format(tree)
    end

    def initialize(config, formatter=DefaultTagFormatter.new)
      @config = config
      @formatter = formatter
    end

    def visit(tree)
      if tree.kind_of? Parser::TagNode
        format_tag(tree)
      elsif tree.kind_of? Parser::Leaf
        tree.join
      else
        tree.map {|node| node.accept(self) }
      end
    end

    def format_tag(tag_node)
      leafs = tag_node.map {|leaf| leaf.accept(self) }
      @formatter.format(tag_node.type, leafs.join.strip, @config)
    end

    def format(tree)
      tree.accept(self).join
    end
  end
end
