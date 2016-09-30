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
        when Parser::IterationNode, Parser::FallbackTagNode
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

    def self.extract_labels(parsed_template, target_format=nil, memo=nil)
      labels = extract_labels_as_ruby_objects(parsed_template, memo)
      labels = pull_up_inner_iterations(labels)

      RecordReader.dump(labels, target_format)
    end

    def self.extract_labels_as_ruby_objects(parsed_template, memo)
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
      iteration_labels = labels.keys.select do |label|
        labels[label].kind_of? Array
      end

      iteration_labels.each {|label| yield label }
    end

    private_class_method :extract_labels_as_ruby_objects
    private_class_method :pull_up_inner_iterations
    private_class_method :each_iteration_label
  end
end
