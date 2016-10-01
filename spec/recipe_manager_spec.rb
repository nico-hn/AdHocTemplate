#!/usr/bin/env ruby

require 'spec_helper'
require 'ad_hoc_template'
require 'ad_hoc_template/recipe_manager'

describe AdHocTemplate do
  describe AdHocTemplate::RecordReader::RecipeReader do
    before do
      @recipe = <<RECIPE
---
template: template.html
tag_type: :default
template_encoding: UTF-8
data: main.aht
data_format: 
data_encoding: 
output_file: 
blocks:
- label: "#authors"
  data: 
  data_format: 
  data_encoding: 
- label: "#authors|works|name"
  data: authors.csv
  data_format: csv
  data_encoding: 'iso-8859-1'
- label: "#authors|bio|name"
  data: authors.csv
  data_format: csv
  data_encoding: 'iso-8859-1'
RECIPE
      @template = <<TEMPLATE
Title: Famous authors of <%= country %> literature

<%#authors:
Name: <%= name %>
Birthplace: <%= birth_place %>
Works:
<%#works|name:
 * <%= title %>
#%>
<%#
<%#bio|name:
Born: <%= birth_date %>
#%>
#%>

#%>
TEMPLATE

      @main_data =<<MAIN_DATA
country: French

///@#authors

name: Albert Camus
birth_place: Algeria

name: Marcel Ayme'
birth_place: France
MAIN_DATA

      @csv_data =<<CSV_DATA
name,title
Albert Camus,"L'E'tranger"
Albert Camus,La Peste
"Marcel Ayme'",Le Passe-muraille
"Marcel Ayme'","Les Contes du chat perche'"
CSV_DATA

      @expected_result =<<EXPECTED_RESULT
Title: Famous authors of French literature

Name: Albert Camus
Birthplace: Algeria
Works:
 * L'E'tranger
 * La Peste

Name: Marcel Ayme'
Birthplace: France
Works:
 * Le Passe-muraille
 * Les Contes du chat perche'

EXPECTED_RESULT
    end

    it 'reads a recipe' do
      reader = AdHocTemplate::RecordReader::RecipeReader.new
      recipe = reader.read_recipe(@recipe)

      expect(recipe['blocks'][0]['data']).to eq('main.aht')
      expect(recipe['blocks'][1]['data']).to eq('authors.csv')
    end

    it '#prepare_block_data reads data into a block from a source file' do
      expected_result = {
        "#authors" => [{"name"=>"Albert Camus"}, {"name"=>"Marcel Ayme'"}],
        "#authors|works|Albert Camus" => [
          {"name"=>"Albert Camus", "title"=>"L'E'tranger"},
          {"name"=>"Albert Camus", "title"=>"La Peste"}],
        "#authors|works|Marcel Ayme'" => [
          {"name"=>"Marcel Ayme'", "title"=>"Le Passe-muraille"},
          {"name"=>"Marcel Ayme'", "title"=>"Les Contes du chat perche'"}]}

      reader = AdHocTemplate::RecordReader::RecipeReader.new
      recipe = reader.read_recipe(@recipe)
      block = recipe['blocks'][1]
      data_file_path = File.expand_path(block['data'])
      csv_data = StringIO.new(@csv_data)
      template_encoding = recipe['template_encoding']
      open_mode = ['r', block['data_encoding'], template_encoding].join(':')
      allow(reader).to receive(:open).with(data_file_path, open_mode).and_yield(csv_data)
      block_data = reader.prepare_block_data(block, template_encoding)
      expect(block_data).to eq(expected_result)
    end

    it '#merge_blocks reads blocks and merge them' do
      expected_result = {
        "country" => "French",
        "#authors" => [{"name"=>"Albert Camus", "birth_place"=>"Algeria"}, {"name"=>"Marcel Ayme'", "birth_place"=>"France"}],
        "#authors|works|Albert Camus" => [
          {"name"=>"Albert Camus", "title"=>"L'E'tranger"},
          {"name"=>"Albert Camus", "title"=>"La Peste"}],
        "#authors|works|Marcel Ayme'" => [
          {"name"=>"Marcel Ayme'", "title"=>"Le Passe-muraille"},
          {"name"=>"Marcel Ayme'", "title"=>"Les Contes du chat perche'"}]}

      reader = AdHocTemplate::RecordReader::RecipeReader.new
      recipe = reader.read_recipe(@recipe)
      template_encoding = recipe['template_encoding']
      allow(reader).to receive(:open).with(File.expand_path(recipe['data']), 'r').and_yield(StringIO.new(@main_data))
      recipe['blocks'].each do |block|
        data_file_path = File.expand_path(block['data'])
        csv_data = StringIO.new(@csv_data)
        open_mode = ['r', block['data_encoding'], template_encoding].join(':')
        allow(reader).to receive(:open).with(data_file_path, open_mode).and_yield(StringIO.new(@csv_data))
      end
      main_block = reader.merge_blocks(recipe)
      expect(main_block).to eq(expected_result)
    end

    it "#merge_blocks' result can be used as input of DataLoader.parse" do
      reader = AdHocTemplate::RecordReader::RecipeReader.new
      recipe = reader.read_recipe(@recipe)
      template_encoding = recipe['template_encoding']
      allow(reader).to receive(:open).with(File.expand_path(recipe['data']), 'r').and_yield(StringIO.new(@main_data))
      recipe['blocks'].each do |block|
        data_file_path = File.expand_path(block['data'])
        csv_data = StringIO.new(@csv_data)
        open_mode = ['r', block['data_encoding'], template_encoding].join(':')
        allow(reader).to receive(:open).with(data_file_path, open_mode).and_yield(StringIO.new(@csv_data))
      end

      main_block = reader.merge_blocks(recipe)
      tree = AdHocTemplate::Parser.parse(@template)
      result = AdHocTemplate::DataLoader.format(tree, main_block)
      expect(result).to eq(@expected_result)
    end
  end
end

