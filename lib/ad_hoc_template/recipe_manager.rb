#!/usr/bin/env ruby

require 'ad_hoc_template'

module AdHocTemplate
  class RecipeReader
    attr_accessor :output_file, :template_encoding

    def initialize
      @default = {}
    end

    def read_recipe(recipe_source)
      recipe = RecordReader::YAMLReader.read_record(recipe_source)
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

    def prepare_block_data(block, template_encoding)
      data_source = read_file(block['data'],
                              block['data_encoding'],
                              template_encoding)
      data_format = prepare_data_format(block)
      RecordReader.read_record(data_source, data_format)
    end

    private

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
        @default['label'] ||= RecordReader::CSVReader::HEADER_POSITION::LEFT
      end
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
end