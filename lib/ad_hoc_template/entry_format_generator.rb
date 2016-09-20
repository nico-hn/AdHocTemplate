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
        when Parser::IterationTagNode, Parser::FallbackTagNode
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

    def self.extract_labels(parsed_template, target_format=nil)
      labels = extract_labels_as_ruby_objects(parsed_template)
      labels = pull_up_inner_iterations(labels)

      RecordReader.dump(labels, target_format)
    end

    def self.extract_labels_as_ruby_objects(parsed_template)
      label_checker = LabelChecker.new
      parsed_template.accept(label_checker)
      label_checker.labels
    end

    def self.pull_up_inner_iterations(labels)
      labels.keys.each do |label|
        sub_records = labels[label]
        if sub_records.kind_of? Array
          sub_records.each do |record|
            record.keys.each do |key|
              if record[key].kind_of? Array
                inner_label = [label, key.sub(/\A#/, '')].join('|')
                labels[inner_label] = record.delete(key)
              end
            end
          end
        end
      end
      labels
    end

    private_class_method :extract_labels_as_ruby_objects
    private_class_method :pull_up_inner_iterations
  end
end
