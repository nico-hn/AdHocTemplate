#!/usr/bin/env ruby

require 'yaml'
require 'json'
require 'csv'

module AdHocTemplate
  module RecordReader
    module YAMLReader
      def self.read_record(yaml_data)
        YAML.load(yaml_data)
      end

      def self.to_yaml(config_data)
        data = RecordReader.read_record(config_data)
        YAML.dump(data)
      end
    end

    module JSONReader
      def self.read_record(json_data)
        JSON.parse(json_data)
      end

      def self.to_json(config_data)
        data = RecordReader.read_record(config_data)
        JSON.dump(data)
      end
    end

    module CSVReader
      def self.read_record(csv_data, label=nil, format=:csv)
        label, sep  = parse_config(format => label)
        header, *data = CSV.new(csv_data, col_sep: sep).to_a
        records = data.map {|row| convert_to_hash(header, row) }
        if label
          { '#' + label => records }
        elsif records.length == 1
          records[0]
        else
          records
        end
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
        field_sep = format == :tsv ? "\t" : CSV::DEFAULT_OPTIONS[:col_sep]
        return label, field_sep
      end

      private_class_method :convert_to_hash
    end

    SEPARATOR = /:\s*/o
    BLOCK_HEAD = /\A\/\/@/o
    ITERATION_HEAD = /\A\/\/@#/o
    EMPTY_LINE = /\A(?:\r?\n|\r)\Z/o
    ITERATION_MARK = /\A#/o
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
        when EMPTY_LINE
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

    def self.read_record(input, source_format=:default)
      source_format, csv_label = parse_source_format(source_format)

      case source_format
      when :default
        ReaderState.new.read_record(input)
      when :yaml
        YAMLReader.read_record(input)
      when :json
        JSONReader.read_record(input)
      when :csv
        CSVReader.read_record(input, csv_label)
      when :tsv
        CSVReader.read_record(input, csv_label, :tsv)
      end
    end

    def self.parse_source_format(source_format)
      return source_format, nil unless source_format.kind_of? Hash

      [:csv, :tsv].each do |format|
        if csv_label = source_format[format]
          return format, csv_label
        end
      end
    end

    private_class_method :parse_source_format
  end
end
