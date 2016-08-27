#!/usr/bin/env ruby

module AdHocTemplate
  module RecordReader
    SEPARATOR = /:\s*/o
    BLOCK_HEAD = /\A\/\/@/o
    ITERATION_HEAD = /\A\/\/@#/o
    EMPTY_LINE = /\A\r?\n\Z/o
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

    def self.read_record(input)
      ReaderState.new.read_record(input)
    end
  end
end