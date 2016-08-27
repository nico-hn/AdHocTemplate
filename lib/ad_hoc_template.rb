require "ad_hoc_template/version"
require "ad_hoc_template/parser"
require "ad_hoc_template/record_reader"

module AdHocTemplate
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

  class Formatter
    def self.convert(record_data, template, tag_formatter=DefaultTagFormatter.new)
      tree = AdHocTemplate::Parser.parse(template)
      record = AdHocTemplate::RecordReader.read_record(record_data)
      AdHocTemplate::Formatter.new(record, tag_formatter).format(tree)
    end

    def initialize(record, tag_formatter=DefaultTagFormatter.new)
      @record = record
      @tag_formatter = tag_formatter
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
          converter = AdHocTemplate::Formatter.new(record, @tag_formatter)
          tag_node.map {|leaf| leaf.accept(converter) }.join
        else
          "".freeze
        end
      end
    end

    def format_tag(tag_node)
      leafs = tag_node.map {|leaf| leaf.accept(self) }
      @tag_formatter.format(tag_node.type, leafs.join.strip, @record)
    end

    def format(tree)
      tree.accept(self).join
    end
  end
end
