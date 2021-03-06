# frozen_string_literal: true

module AdHocTemplate
  module EntryFormatGenerator
    DEFAULT_ENCODING = Encoding.default_external.names[0]

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
        sub_checker = self
        iteration_label = tree.type

        if iteration_label
          sub_checker = self.class.new
          @labels[iteration_label] = [sub_checker.labels]
        end

        tree.each {|node| node.accept(sub_checker, memo) }
      end
    end

    def self.extract_form(parsed_template, target_format=nil, memo=nil)
      labels = extract_form_as_ruby_objects(parsed_template, memo)
      labels = pull_up_inner_iterations(labels)

      RecordReader.dump(labels, target_format)
    end

    def self.extract_recipes_from_template_files(template_paths,
                                                 tag_type=:default,
                                                 encoding=DEFAULT_ENCODING)
      recipes = map_read_files(template_paths, encoding) do |path, src|
        extract_recipe(src, path, tag_type, encoding)
      end

      recipes.join
    end

    def self.map_read_files(paths, encoding=DEFAULT_ENCODING)
      paths.map do |path|
        full_path = File.expand_path(path)
        yield path, File.open(full_path, "rb:BOM|#{encoding}", &:read)
      end
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
      {
        'template' => template_path,
        'tag_type' => tag_type,
        'template_encoding' => encoding,
        'data' => nil,
        'data_format' => nil,
        'data_encoding' => nil,
        'output_file' => nil,
        'blocks' => [],
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

    private_class_method :map_read_files
    private_class_method :extract_form_as_ruby_objects
    private_class_method :pull_up_inner_iterations
    private_class_method :each_iteration_label
    private_class_method :recipe_entry, :recipe_block_entry
  end
end
