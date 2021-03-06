# frozen_string_literal: true

require 'ad_hoc_template/version'
require 'ad_hoc_template/parser'
require 'ad_hoc_template/record_reader'
require 'ad_hoc_template/default_tag_formatter'
require 'ad_hoc_template/pseudohiki_formatter'
require 'ad_hoc_template/entry_format_generator'
require 'ad_hoc_template/config_manager'

module AdHocTemplate
  class DataLoader
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

    attr_reader :record, :tag_formatter

    def initialize(record, tag_formatter=DefaultTagFormatter.new)
      @record = record
      @tag_formatter = tag_formatter
    end

    def visit(tree, memo)
      case tree
      when Parser::IterationNode
        format_iteration_tag(tree, self, memo)
      when Parser::FallbackNode
        ''
      when Parser::ValueNode
        format_value_tag(tree, self, memo)
      when Parser::Leaf
        tree.join
      else
        tree.map {|node| node.accept(self, memo) }
      end
    end

    def format_iteration_tag(iteration_tag_node, data_loader, memo)
      tag_node = iteration_tag_node.cast

      prepare_sub_records(iteration_tag_node, data_loader).map do |record|
        format_sub_nodes(tag_node, record, data_loader, memo)
      end
    end

    def format_value_tag(tag_node, data_loader, memo)
      leafs = tag_node.format_sub_nodes(data_loader, memo).strip
      data_loader.tag_formatter.format(tag_node.type, leafs, data_loader.record)
    end

    def format(tree, memo=nil)
      tree.accept(self, memo).join
    end

    def new_with_record(record)
      self.class.new(record, @tag_formatter)
    end

    protected

    def sub_records(tag_node)
      @record[tag_node.type] || [@record]
    end

    private

    def prepare_sub_records(tag_node, data_loader)
      inner_labels = tag_node.inner_labels
      return data_loader.sub_records(tag_node) unless inner_labels
      data_loader.sub_records(tag_node).map do |record|
        merge_inner_iteration_records(record, inner_labels, data_loader)
      end
    end

    def merge_inner_iteration_records(record, inner_labels, data_loader)
      new_record = nil
      inner_labels.each do |label|
        inner_data = data_loader.record[label.full_label(record)]
        if inner_data
          new_record ||= record.dup
          new_record[label.inner_label] = inner_data
        end
      end
      new_record || record
    end

    def format_sub_nodes(tag_node, record, data_loader, memo)
      if tag_node.contains_any_value_assigned_tag_node?(record)
        tag_node.format_sub_nodes(data_loader.new_with_record(record), memo)
      elsif tag_node.contains_any_fallback_tag?
        format_fallback_tags(tag_node.select_fallback_nodes,
                             data_loader.new_with_record(record), memo)
      else
        ''
      end
    end

    def format_fallback_tags(fallback_nodes, data_loader, memo)
      fallback_nodes.map do |fallback_node|
        fallback_node.format_sub_nodes(data_loader, memo)
      end
    end
  end

  def self.render(record_data, template, tag_type=:default,
                  data_format=:default, tag_formatter=DefaultTagFormatter.new)
    tree = Parser.parse(template, tag_type)
    record = RecordReader.read_record(record_data, data_format)
    DataLoader.format(tree, record, tag_formatter)
  end

  def self.local_settings(&config_block)
    ConfigManager.configure(&config_block)
  end
end
