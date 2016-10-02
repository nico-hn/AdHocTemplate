#!/usr/bin/env ruby

module AdHocTemplate
  module EntryFormatGenerator
    class LabelChecker
      attr_reader :labels
      def initialize
        @labels = {}
      end

      def visit(tree, memo)
        case tree
        when Parser::IterationNode, Parser::FallbackNode
          visit_iteration_tag_node(tree, memo)
        when Parser::TagNode
          @labels[tree.join.strip] = nil
        when Parser::Node
          tree.each {|node| node.accept(self, memo) }
        end
      end

      private

      def visit_iteration_tag_node(tree, memo)
        if iteration_label = tree.type
          sub_checker = self.class.new
          @labels[iteration_label] = [sub_checker.labels]
          tree.each { |node| node.accept(sub_checker, memo) }
        else
          tree.each {|node| node.accept(self, memo) }
        end
      end
    end

    def self.extract_form(parsed_template, target_format=nil, memo=nil)
      labels = extract_form_as_ruby_objects(parsed_template, memo)
      labels = pull_up_inner_iterations(labels)

      RecordReader.dump(labels, target_format)
    end

    def self.extract_recipe(template_source, template_path,
                            tag_type=:default, encoding='UTF-8')
      recipe = recipe_entry(template_path, tag_type, encoding)
      parsed_template = Parser.parse(template_source, tag_type)
      extract_iteration_labels(parsed_template).each do |label|
        recipe['blocks'].push recipe_block_entry(label) if label.start_with? '#'
      end

      RecordReader.dump(recipe, :yaml)
    end

    def self.extract_iteration_labels(parsed_template, memo=nil)
      labels = extract_form_as_ruby_objects(parsed_template, memo)
      pull_up_inner_iterations(labels).keys
    end

    def self.extract_form_as_ruby_objects(parsed_template, memo)
      label_checker = LabelChecker.new
      parsed_template.accept(label_checker, memo)
      label_checker.labels
    end

    def self.pull_up_inner_iterations(labels)
      each_iteration_label(labels) do |label|
        labels[label].each do |record|
          each_iteration_label(record) do |key|
            inner_label = [label, key.sub(/\A#/, '')].join('|')
            labels[inner_label] = record.delete(key)
          end
        end
      end
      labels
    end

    def self.each_iteration_label(labels)
      labels.keys.each do |label|
        yield label if labels[label].kind_of? Array
      end
    end

    def self.recipe_entry(template_path, tag_type, encoding)
      recipe = {
        'template' => template_path,
        'tag_type' => tag_type,
        'template_encoding' => encoding,
        'data' => nil,
        'data_format' => nil,
        'data_encoding' => nil,
        'output_file' => nil,
        'blocks' => []
      }
    end

    def self.recipe_block_entry(label)
      {
        'label' => label,
        'data' => nil,
        'data_format' => nil,
        'data_encoding' => nil,
      }
    end

    private_class_method :extract_form_as_ruby_objects
    private_class_method :pull_up_inner_iterations
    private_class_method :each_iteration_label
    private_class_method :recipe_entry, :recipe_block_entry
  end
end
