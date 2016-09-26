require "ad_hoc_template/version"
require "ad_hoc_template/parser"
require "ad_hoc_template/record_reader"
require "ad_hoc_template/default_tag_formatter"
require "ad_hoc_template/pseudohiki_formatter"
require "ad_hoc_template/entry_format_generator"

module AdHocTemplate
  class DataLoader
    class InnerLabel
      attr_reader :inner_label

      def self.labels(inner_labels, cur_label)
        inner_labels.map {|label| new(label, cur_label) }
      end

      def initialize(inner_label, cur_label)
        @inner_label = inner_label
        @label, @key = inner_label.sub(/\A#/, ''.freeze).split(/\|/, 2)
        @cur_label = cur_label
      end

      def full_label(record)
        [@cur_label, @label, record[@key]].join('|')
      end
    end

    def self.format(template, record, tag_formatter=DefaultTagFormatter.new)
      if record.kind_of? Array
        return format_multi_records(template, record, tag_formatter)
      end
      new(record, tag_formatter).format(template)
    end

    def self.format_multi_records(template, records,
                                  tag_formatter=DefaultTagFormatter.new)
      records.map do |record|
        new(record, tag_formatter).format(template)
      end.join
    end

    def initialize(record, tag_formatter=DefaultTagFormatter.new)
      @record = record
      @tag_formatter = tag_formatter
    end

    def visit(tree, memo)
      case tree
      when Parser::IterationTagNode
        format_iteration_tag(tree, memo)
      when Parser::FallbackTagNode
        ''.freeze
      when Parser::TagNode
        format_tag(tree, memo)
      when Parser::Leaf
        tree.join
      else
        tree.map {|node| node.accept(self, memo) }
      end
    end

    def format_iteration_tag(iteration_tag_node, memo)
      tag_node = cast(iteration_tag_node)

      prepare_sub_records(iteration_tag_node).map do |record|
        if tag_node.contains_any_value_assigned_tag_node?(record)
          visit_with_sub_record(tag_node, record, memo)
        elsif fallback_nodes = select_fallback_nodes(tag_node)
          format_fallback_tags(fallback_nodes, record, memo)
        else
          "".freeze
        end
      end
    end

    def format_tag(tag_node, memo)
      leafs = tag_node.map {|leaf| leaf.accept(self, memo) }
      @tag_formatter.format(tag_node.type, leafs.join.strip, @record)
    end

    def format(tree, memo=nil)
      tree.accept(self, memo).join
    end

    private

    def cast(node, node_type=Parser::TagNode)
      node_type.new.concat(node.clone)
    end

    def prepare_sub_records(tag_node)
      cur_label = tag_node.type
      sub_records = @record[cur_label]||[@record]
      return sub_records unless cur_label
      inner_labels = tag_node.inner_iteration_tag_labels
      return sub_records unless inner_labels
      inner_labels = InnerLabel.labels(inner_labels, cur_label)
      sub_records.map do |record|
        prepare_inner_iteration_records(record, inner_labels)
      end
    end

    def prepare_inner_iteration_records(record, inner_labels)
      new_record = nil
      inner_labels.each do |label|
        if inner_data = @record[label.full_label(record)]
          new_record ||= record.dup
          new_record[label.inner_label] = inner_data
        end
      end
      new_record || record
    end

    def visit_with_sub_record(tag_node, record, memo)
      data_loader = AdHocTemplate::DataLoader.new(record, @tag_formatter)
      tag_node.map {|leaf| leaf.accept(data_loader, memo) }.join
    end

    def select_fallback_nodes(tag_node)
      tags = tag_node.select {|sub_node| sub_node.kind_of? Parser::FallbackTagNode }
      tags.empty? ? nil : tags
    end

    def format_fallback_tags(fallback_nodes, record, memo)
      data_loader = AdHocTemplate::DataLoader.new(record, @tag_formatter)
      fallback_nodes.map do |fallback_node|
        node = cast(fallback_node, Parser::IterationTagNode)
        node.contains_any_value_tag? ? node.accept(data_loader, memo) : node.join
      end
    end
  end

  def self.render(record_data, template, tag_type=:default, data_format=:default,
                  tag_formatter=DefaultTagFormatter.new)
    tree = Parser.parse(template, tag_type)
    record = RecordReader.read_record(record_data, data_format)
    DataLoader.format(tree, record, tag_formatter)
  end
end
