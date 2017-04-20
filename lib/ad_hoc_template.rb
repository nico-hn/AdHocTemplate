require "ad_hoc_template/version"
require "ad_hoc_template/parser"
require "ad_hoc_template/record_reader"
require "ad_hoc_template/default_tag_formatter"
require "ad_hoc_template/pseudohiki_formatter"
require "ad_hoc_template/entry_format_generator"
require "ad_hoc_template/config_manager"

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

    attr_reader :record, :tag_formatter

    def visit(tree, memo)
      case tree
      when Parser::IterationNode
        format_iteration_tag(tree, self, memo)
      when Parser::FallbackNode
        ''.freeze
      when Parser::ValueNode
        format_value_tag(tree, self, memo)
      when Parser::Leaf
        tree.join
      else
        tree.map {|node| node.accept(self, memo) }
      end
    end

    def format_iteration_tag(iteration_tag_node, inner_label, memo)
      tag_node = cast(iteration_tag_node)

      prepare_sub_records(iteration_tag_node, inner_label.record).map do |record|
        if tag_node.contains_any_value_assigned_tag_node?(record)
          visit_with_sub_record(tag_node, record, memo, inner_label.tag_formatter)
        elsif fallback_nodes = select_fallback_nodes(tag_node)
          format_fallback_tags(fallback_nodes, record, memo, inner_label.tag_formatter)
        else
          "".freeze
        end
      end
    end

    def format_value_tag(tag_node, inner_label, memo)
      leafs = tag_node.map {|leaf| leaf.accept(self, memo) }
      inner_label.tag_formatter.format(tag_node.type, leafs.join.strip, inner_label.record)
    end

    def format(tree, memo=nil)
      tree.accept(self, memo).join
    end

    private

    def cast(node, node_type=Parser::TagNode)
      node_type.new.concat(node.clone)
    end

    def prepare_sub_records(tag_node, self_record)
      cur_label = tag_node.type
      sub_records = self_record[cur_label]||[self_record]
      return sub_records unless cur_label
      inner_labels = tag_node.inner_iteration_tag_labels
      return sub_records unless inner_labels
      inner_labels = InnerLabel.labels(inner_labels, cur_label)
      sub_records.map do |record|
        prepare_inner_iteration_records(record, inner_labels, self_record)
      end
    end

    def prepare_inner_iteration_records(record, inner_labels, self_record)
      new_record = nil
      inner_labels.each do |label|
        if inner_data = self_record[label.full_label(record)]
          new_record ||= record.dup
          new_record[label.inner_label] = inner_data
        end
      end
      new_record || record
    end

    def visit_with_sub_record(tag_node, record, memo, self_tag_formatter)
      data_loader = AdHocTemplate::DataLoader.new(record, self_tag_formatter)
      tag_node.map {|leaf| leaf.accept(data_loader, memo) }.join
    end

    def select_fallback_nodes(tag_node)
      tags = tag_node.select {|sub_node| sub_node.kind_of? Parser::FallbackNode }
      tags.empty? ? nil : tags
    end

    def format_fallback_tags(fallback_nodes, record, memo, self_tag_formatter)
      data_loader = AdHocTemplate::DataLoader.new(record, self_tag_formatter)
      fallback_nodes.map do |fallback_node|
        node = cast(fallback_node, Parser::IterationNode)
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

  def self.local_settings(&config_block)
    ConfigManager.configure(&config_block)
  end
end
