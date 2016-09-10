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

    module DefaultFormat
      def self.dump(labels)
        iterations, keys = labels.partition {|e| e[1] }.map {|e| e.map(&:first) }

        key_value_part = format_key_names(keys)

        iteration_part = iterations.map do |iteration_label|
          kv_part = format_key_names(labels[iteration_label][0].keys)
          "///@#{iteration_label}#{$/*2}#{kv_part}"
        end.join($/)

        [key_value_part, iteration_part].join($/)
      end

      def self.format_key_names(key_names)
        key_names.map {|key| "#{key}: #{$/}" }.join
      end

      private_class_method :format_key_names
    end

    def self.extract_labels(parsed_template, data_format=nil)
      labels = extract_labels_as_ruby_objects(parsed_template)

      case data_format
      when :yaml
        RecordReader::YAMLReader.dump(labels)
      when :json
        RecordReader::JSONReader.dump(labels)
      else
        DefaultFormat.dump(labels)
      end
    end

    def self.extract_labels_as_ruby_objects(parsed_template)
      label_checker = LabelChecker.new
      parsed_template.accept(label_checker)
      label_checker.labels
    end

    private_class_method :extract_labels_as_ruby_objects
  end
end
