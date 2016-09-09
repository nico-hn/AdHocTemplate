#!/usr/bin/env ruby

module AdHocTemplate
  module EntryFormatGenerator
    class LabelChecker
      attr_reader :labels
      def initialize
        @labels = {}
      end

      def visit(tree)
        case tree
        when Parser::IterationTagNode
          visit_iteration_tag_node(tree)
        when Parser::TagNode
          @labels[tree.join.strip] = nil
        when Parser::Node
          tree.each {|node| node.accept(self) }
        end
      end

      private

      def visit_iteration_tag_node(tree)
        if iteration_label = tree.type
          sub_checker = self.class.new
          @labels[iteration_label] = [sub_checker.labels]
          tree.each { |node| node.accept(sub_checker) }
        else
          tree.each {|node| node.accept(self) }
        end
      end
    end

    def self.extract_labels(parsed_template, data_format=nil)
      labels = extract_labels_as_ruby_objects(parsed_template)

      case data_format
      when :yaml
        YAML.dump(labels)
      when :json
        JSON.dump(labels)
      else
        labels_in_default_format(labels)
      end
    end

    def self.extract_labels_as_ruby_objects(parsed_template)
      label_checker = LabelChecker.new
      parsed_template.accept(label_checker)
      label_checker.labels
    end

    def self.labels_in_default_format(labels)
      keys = []
      iterations = []
      labels.each do |key, val|
        if val.kind_of? Array
          iterations.push key
        else
          keys.push key
        end
      end

      key_value_part = keys.map {|key| "#{key}: " }.join($/)

      iteration_part = iterations.map do |iteration_label|
        header = "///@#{iteration_label}#{$/}#{$/}"
        key_values = labels[iteration_label][0].keys.map {|key| "#{key}: " }.join($/)
        header + key_values + $/
      end.join($/*2)

      [key_value_part, iteration_part].join($/*2)
    end

    private_class_method :extract_labels_as_ruby_objects
  end
end
