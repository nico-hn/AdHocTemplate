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
          if iteration_label = tree.type
            sub_checker = self.class.new
            @labels[iteration_label] = [sub_checker.labels]
            tree.each { |node| node.accept(sub_checker) }
          else
            tree.each {|node| node.accept(self) }
          end
        when Parser::TagNode
          @labels[tree.join.strip] = nil
        when Parser::Node
          tree.each {|node| node.accept(self) }
        end
      end
    end

    def self.extract_labels(parsed_template, data_format=nil)
      label_checker = LabelChecker.new
      parsed_template.accept(label_checker)
      labels = label_checker.labels
      case data_format
      when :yaml
        YAML.dump(labels)
      when :json
        JSON.dump(labels)
      else
        labels
      end
    end
  end
end
