#!/usr/bin/env ruby

require 'ad_hoc_template'
require 'ad_hoc_template/utils'

module AdHocTemplate
  class RecipeManager
    include Utils

    attr_reader :output_file, :template_encoding, :template
    attr_reader :records, :recipe

    def self.update_output_files_in_recipe(recipe)
      recipe_source = open(File.expand_path(recipe)) {|file| file.read }
      recipes = YAML.load_stream(recipe_source)
      recipes.each do |recipe|
        manager = new(recipe)
        manager.update_output_file
      end
    end

    def self.new_recipe_from_source(source)
      new(source).tap {|manager| manager.load_records }
    end

    def initialize(recipe_source)
      @default = {}
      read_recipe(recipe_source)
    end

    def read_recipe(recipe_source)
      @recipe = if recipe_source.kind_of? String
                  RecordReader::YAMLReader.read_record(recipe_source)
                else
                  recipe_source
                end
      setup_default!(@recipe)
      @template_encoding = @default['template_encoding']
      @output_file = @default['output_file']
      @recipe
    end

    def load_records
      @records = prepare_block_data(@recipe).tap do |main_block|
        @recipe['blocks'].each do |block_source|
          block = prepare_block_data(block_source)
          block.keys.each do |key|
            main_block[key] ||= block[key]
          end
        end
      end
    end

    def prepare_block_data(block)
      determine_data_format!(block)
      data_source = read_file(block['data'],
                              block['data_encoding'])
      data_format = prepare_data_format(block)
      RecordReader.read_record(data_source, data_format)
    end

    def parse_template
      template_path = File.expand_path(@recipe['template'])
      template_source = open(template_path,
                             open_mode(@template_encoding)) do |file|
        file.read
      end
      tag_type = @recipe['tag_type'] || :default
      tag_type = tag_type.to_sym unless tag_type.kind_of? Symbol
      @template = Parser.parse(template_source, tag_type)
    end

    def update_output_file
      @records ||= load_records
      parse_template
      content = AdHocTemplate::DataLoader.format(@template, @records)
      mode = @template_encoding ? "wb:#{@template_encoding}" : 'wb'
      if @output_file
        open(File.expand_path(@output_file), mode) {|file| file.print content }
      else
        STDOUT.print content
      end
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

    def determine_data_format!(block)
      data_format = block['data_format']
      if not data_format and block['data']
        data_format = guess_file_format(block['data'])
      end

      block['data_format'] ||= data_format
    end

    def read_file(file_name, encoding)
      open(File.expand_path(file_name),
           open_mode(encoding)) do |file|
        file.read
      end
    end

    def open_mode(encoding)
      encoding ||= Encoding.default_external.names[0]
      mode = "rb"
      return mode unless encoding and not encoding.empty?
      bom = /\AUTF/i =~ encoding ? 'BOM|' : ''
      mode += ":#{bom}#{encoding}"
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
