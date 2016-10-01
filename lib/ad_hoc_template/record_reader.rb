#!/usr/bin/env ruby

require 'yaml'
require 'json'
require 'csv'

module AdHocTemplate
  module RecordReader
    module YAMLReader
      def self.read_record(yaml_data)
        RecordReader.convert_values_to_string(YAML.load(yaml_data))
      end

      def self.dump(config_data)
        data = RecordReader.parse_if_necessary(config_data)
        YAML.dump(data)
      end
    end

    module JSONReader
      def self.read_record(json_data)
        RecordReader.convert_values_to_string(JSON.parse(json_data))
      end

      def self.dump(config_data)
        data = RecordReader.parse_if_necessary(config_data)
        JSON.pretty_generate(data)
      end
    end

    module CSVReader
      COL_SEP = {
        csv: CSV::DEFAULT_OPTIONS[:col_sep],
        tsv: "\t"
      }

      module HEADER_POSITION
        TOP = '__header_top__'
        LEFT = '__header_left__'
      end

      class NotSupportedError < StandardError; end

      def self.read_record(csv_data, config={ csv: nil })
        label, sep  = parse_config(config)
        header, *data = csv_to_array(csv_data, sep, label)
        csv_records = data.map {|row| convert_to_hash(header, row) }
        if label and label.index('|')
          return compose_inner_iteration_records(csv_records, label)
        end
        compose_record(csv_records, label)
      end

      def self.dump(config_data, col_sep=COL_SEP[:csv])
        data = RecordReader.parse_if_necessary(config_data)
        raise NotSupportedError unless csv_compatible_format?(data)

        if kv_pairs = find_sub_records(data)
          records = hashes_to_arrays(kv_pairs)
        else
          records = data.to_a.transpose
        end

        array_to_csv(records, col_sep)
      end

      def self.convert_to_hash(header, row_array)
        {}.tap do |record|
          header.zip(row_array).each do |key, value|
            record[key] = value
          end
        end
        # if RUBY_VERSION >= 2.1.0: header.zip(row_array).to_h
      end

      def self.parse_config(config)
        case config
        when Symbol
          format, label = config, nil
        when String
          format, label = :csv, config
        when Hash
          format, label = config.to_a[0]
        end
        col_sep = COL_SEP[format||:csv]
        return label, col_sep
      end

      def self.csv_to_array(csv_data, col_sep, label)
        array = CSV.new(csv_data, col_sep: col_sep).to_a
        if not label or label == HEADER_POSITION::LEFT
          array = array.transpose
        end
        array
      end

      def self.compose_record(csv_records, label)
        if label
          { '#' + label => csv_records }
        elsif csv_records.length == 1
          csv_records[0]
        else
          csv_records
        end
      end

      def self.compose_inner_iteration_records(csv_records, given_label,
                                               main_record={})
        outer_label, inner_label, key = ('#' + given_label).split(/\|/, 3)
        values = inner_iteration_records(csv_records, key)
        labels = inner_iteration_labels(outer_label, inner_label, values.keys)
        unless main_record[outer_label]
          main_record[outer_label] = values.keys.map {|k| { key => k } }
        end
        values.keys.each {|k| main_record[labels[k]] = values[k] }
        main_record
      end

      def self.inner_iteration_records(csv_records, key)
        values = Hash.new {|h, k| h[k] = [] }
        csv_records.each {|record| values[record[key]].push record }
        values
      end

      def self.inner_iteration_labels(outer_label, inner_label, keys)
        labels = keys.inject({}) do |h, key|
          h[key] = [outer_label, inner_label, key].join('|')
          h
        end
      end

      def self.csv_compatible_format?(data)
        iteration_blocks_count = data.values.select {|v| v.kind_of? Array }.size
        iteration_blocks_count == 0 or (iteration_blocks_count == 1 && data.size == 1)
      end

      def self.hashes_to_arrays(data)
        headers = data.max_by {|h| h.keys.size }.keys
        records = data.map {|record| headers.map {|header| record[header] } }
        records.unshift headers
      end

      def self.find_sub_records(data)
        data.values.find {|v| v.kind_of? Array }
      end

      def self.array_to_csv(records, col_sep)
        # I do not adopt "records.map {|rec| rec.to_csv }.join",
        # because I'm not sure if it is sufficient for certain data or not.
        # For example, a field value may contain carriage returns or line feeds,
        # and in that case, improper handling of the end of record would be damaging.

        CSV.generate('', col_sep: col_sep) do |csv|
          records.each {|record| csv << record }
        end
      end

      private_class_method :convert_to_hash, :parse_config
      private_class_method :csv_to_array, :compose_record
      private_class_method :compose_inner_iteration_records
      private_class_method :inner_iteration_records
      private_class_method :inner_iteration_labels
      private_class_method :csv_compatible_format?, :hashes_to_arrays
      private_class_method :find_sub_records, :array_to_csv
    end

    module TSVReader
      COL_SEP = CSVReader::COL_SEP

      def self.read_record(tsv_data, config={ tsv: nil })
        config = { tsv: config } if config.kind_of? String
        CSVReader.read_record(tsv_data, config)
      end

      def self.dump(config_data, col_sep=COL_SEP[:tsv])
        CSVReader.dump(config_data, col_sep)
      end
    end

    module DefaultFormReader
      SEPARATOR = /:\s*/o
      BLOCK_HEAD = /\A\/\/\/@/o
      ITERATION_HEAD = /\A\/\/\/@#/o
      EMPTY_LINE = /\A#{LINE_END_STR}\Z/o
      ITERATION_MARK = /\A#/o
      COMMENT_HEAD = /\A\/\/\/\//
      READERS_RE = {
        key_value: SEPARATOR,
        iteration: ITERATION_HEAD,
        block: BLOCK_HEAD,
        empty_line: EMPTY_LINE,
      }

      class ReaderState
        attr_accessor :current_block_label

        def initialize(config={}, stack=[])
          @stack = stack
          @configs = [config]
          setup_reader
        end

        def push(reader)
          @stack.push reader
        end

        def pop
          @stack.pop unless @stack.length == 1
        end

        def setup_stack(line)
          @stack[-1].setup_stack(line)
        end

        def current_reader
          @stack[-1]
        end

        def read(line)
          @stack[-1].read(line)
        end

        def push_new_record
          new_record = {}
          @configs.push new_record
          new_record
        end

        def pop_current_record
          @configs.pop
        end

        def current_record
          @configs[-1]
        end

        def parsed_record
          @configs[0]
        end

        def read_record(lines)
          lines = lines.each_line.to_a if lines.kind_of? String
          lines.each do |line|
            setup_stack(line)
            read(line)
          end
          remove_trailing_empty_lines_from_last_block!
          parsed_record
        end

        def last_block_value
          current_record[current_block_label]
        end

        def remove_trailing_empty_lines_from_last_block!
          if current_reader.kind_of? BlockReader
            last_block_value.sub!(/(#{$/})+\Z/, $/)
          end
        end

        private

        def setup_reader
          Reader.setup_reader(self)
        end
      end

      class Reader
        def self.setup_reader(stack)
          readers = {}
          {
            base: BaseReader,
            key_value: KeyValueReader,
            block: BlockReader,
            iteration: IterationReader,
          }.each do |k, v|
            readers[k] = v.new(stack, readers)
          end
          stack.push readers[:base]
          readers
        end

        def initialize(stack, readers)
          @stack = stack
          @readers = readers
        end

        def pop_stack
          @stack.pop
        end

        def read(line)
        end

        private

        def push_reader_if_match(line, readers)
          readers.each do |reader|
            return @stack.push(@readers[reader]) if READERS_RE[reader] === line
          end
        end

        def setup_new_block(line, initial_value)
          label = line.sub(BLOCK_HEAD, "").chomp
          @stack.current_record[label] ||= initial_value
          @stack.current_block_label = label
        end
      end


      class BaseReader < Reader
        def setup_stack(line)
          push_reader_if_match(line, [:iteration, :block, :key_value])
        end
      end

      class KeyValueReader < Reader
        def setup_stack(line)
          case line
          when EMPTY_LINE, ITERATION_HEAD, BLOCK_HEAD
            pop_stack
          end
          push_reader_if_match(line, [:iteration, :block])
        end

        def read(line)
          return if COMMENT_HEAD =~ line
          key, value = line.split(SEPARATOR, 2)
          @stack.current_record[key] = value.chomp
        end
      end

      class BlockReader < Reader
        def setup_stack(line)
          case line
          when ITERATION_HEAD, BLOCK_HEAD
            @stack.remove_trailing_empty_lines_from_last_block!
            pop_stack
          end
          push_reader_if_match(line, [:iteration, :block])
        end

        def read(line)
          block_value = @stack.last_block_value
          case line
          when BLOCK_HEAD
            setup_new_block(line, String.new)
          when EMPTY_LINE, COMMENT_HEAD
            block_value << line unless block_value.empty?
          else
            block_value << line
          end
        end
      end

      class IterationReader < Reader
        def setup_stack(line)
          case line
          when ITERATION_HEAD
            @stack.pop_current_record
          when BLOCK_HEAD
            @stack.pop_current_record
            pop_stack
            @stack.push @readers[:block]
          when SEPARATOR
            @stack.pop_current_record
            @stack.last_block_value.push @stack.push_new_record
            @stack.push @readers[:key_value]
          end
        end

        def read(line)
          case line
          when ITERATION_HEAD
            setup_new_block(line, [])
            @stack.push_new_record
          end
        end
      end

      def self.read_record(input)
        ReaderState.new.read_record(input)
      end

      def self.dump(labels)
        iteration_keys, kv_keys, block_keys = categorize_keys(labels)

        key_value_part = format_key_value_pairs(kv_keys, labels)
        iteration_part = format_iteration_block(iteration_keys, labels)
        block_part = format_key_value_block(block_keys, labels)

        [key_value_part, iteration_part, block_part].join($/).sub(/(#{$/}+)\Z/, $/)
      end

      def self.format_key_value_pairs(key_names, labels={})
        key_names.map {|key| "#{key}: #{labels[key]}#{$/}" }.join
      end

      def self.format_key_value_block(key_names, labels)
        [].tap do |blocks|
          key_names.each do |key|
            blocks.push "///@#{key}#{$/*2}#{labels[key]}"
          end
        end.join($/)
      end

      def self.format_iteration_block(key_names, labels)
        key_names.map do |iteration_label|
          iteration_block = ["///@#{iteration_label}#{$/}"]
          labels[iteration_label].each do |sub_record|
             iteration_block.push format_key_value_pairs(sub_record.keys, sub_record)
          end
          iteration_block.join($/)
        end.join($/)
      end

      def self.categorize_keys(labels)
        iteration_part, rest = labels.partition do |e|
          e[1].kind_of? Array
        end.map {|e| e.map(&:first) }

        block_part, key_value_part = rest.partition do |e|
          LINE_END_RE =~ labels[e]
        end

        return iteration_part, key_value_part, block_part
      end

      private_class_method :format_key_value_pairs
      private_class_method :format_key_value_block
      private_class_method :format_iteration_block
      private_class_method :categorize_keys
    end

    class RecipeReader
      attr_accessor :output_file, :template_encoding

      def initialize
        @default = {}
      end

      def read_recipe(recipe_source)
        recipe = YAMLReader.read_record(recipe_source)
        setup_default!(recipe)
        @template_encoding = @default['template_encoding']
        @output_file = @default['output_file']
        recipe
      end

      def merge_blocks(recipe)
        prepare_block_data(recipe, @template_encoding).tap do |main_block|
          recipe['blocks'].each do |block_source|
            block = prepare_block_data(block_source, @template_encoding)
            block.keys.each do |key|
              main_block[key] ||= block[key]
            end
          end
        end
      end

      def setup_default!(recipe)
        recipe.each do |key, val|
          @default[key] = val unless val.kind_of? Array
        end

        recipe['blocks'].each do |block|
          @default.keys.each do |key|
            block[key] ||= @default[key]
          end
        end
        setup_main_label
      end

      def setup_main_label
        if data_format = @default['data_format'] and
            [:csv, :tsv].include? data_format
          @default['label'] ||= CSVReader::HEADER_POSITION::LEFT
        end
      end

      def prepare_block_data(block, template_encoding)
        data_source = read_file(block['data'],
                                block['data_encoding'],
                                template_encoding)
        data_format = prepare_data_format(block)
        RecordReader.read_record(data_source, data_format)
      end

      def read_file(file_name, encoding, template_encoding)
        open(File.expand_path(file_name),
             open_mode(encoding, template_encoding)) do |file|
          file.read
        end
      end

      def open_mode(encoding, template_encoding)
        mode = "r"
        if encoding and not encoding.empty?
          mode += ":#{encoding}"
        end
        if mode[':'] and template_encoding and not template_encoding.empty?
          mode += ":#{template_encoding}"
        end
        mode
      end

      def prepare_data_format(block)
        data_format = block['data_format']
        if not data_format or data_format.empty?
          data_format = :default
        end
        data_format = data_format.to_sym
        return data_format unless [:csv, :tsv].include? data_format
        if label = block['label']
          label = label.sub(/\A#/, '')
          data_format = { data_format => label }
        end
        data_format
      end
    end

    FORMAT_NAME_TO_READER = {
      yaml: YAMLReader,
      json: JSONReader,
      csv: CSVReader,
      tsv: TSVReader,
      default: DefaultFormReader,
    }

    FORMAT_NAME_TO_READER.default = DefaultFormReader

    def self.dump(data_source, target_format=:default)
      FORMAT_NAME_TO_READER[target_format].dump(data_source)
    end

    def self.read_record(input, source_format=:default)
      case source_format
      when :csv, :tsv, Hash
        CSVReader.read_record(input, source_format)
      else
        FORMAT_NAME_TO_READER[source_format].read_record(input)
      end
    end

    def self.parse_if_necessary(source)
      source.kind_of?(String) ? read_record(source) : source
    end

    def self.convert_values_to_string(data)
      data.each do |k, v|
        if v.kind_of? Array
          v.each {|sub_rec| convert_values_to_string(sub_rec) }
        elsif v and not v.kind_of? String
          data[k] = v.to_s
        end
      end
    end
  end
end
