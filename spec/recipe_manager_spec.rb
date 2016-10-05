#!/usr/bin/env ruby

require 'spec_helper'
require 'ad_hoc_template'
require 'ad_hoc_template/recipe_manager'

describe AdHocTemplate do
  describe AdHocTemplate::RecipeManager do
    before do
      @recipe = <<RECIPE
---
template: template.html
tag_type: :default
template_encoding: UTF-8
data: main.aht
data_format: 
data_encoding: 
output_file: output.html
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

      @parsed_template = [
        ["Title: Famous authors of "], [["country "]], [" literature\n\n"],
        [["Name: "], [["name "]], ["\nBirthplace: "], [["birth_place "]],
          ["\nWorks:\n"], [[" * "], [["title "]], ["\n"]], [[""],
            [["Born: "], [["birth_date "]], ["\n"]]], ["\n"]]]

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
      reader = AdHocTemplate::RecipeManager.new(@recipe)
      recipe = reader.recipe

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

      reader = AdHocTemplate::RecipeManager.new(@recipe)
      recipe = reader.recipe
      block = recipe['blocks'][1]
      data_file_path = File.expand_path(block['data'])
      csv_data = StringIO.new(@csv_data)
      open_mode = ['rb', block['data_encoding']].join(':')
      allow(reader).to receive(:open).with(data_file_path, open_mode).and_yield(csv_data)
      block_data = reader.prepare_block_data(block)
      expect(block_data).to eq(expected_result)
    end

    it '#prepare_block_data guesses data_format from the extention of data file' do
      recipe_source = <<RECIPE
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
  data_format: 
  data_encoding: 'iso-8859-1'
RECIPE

      expected_result = {
        "#authors" => [{"name"=>"Albert Camus"}, {"name"=>"Marcel Ayme'"}],
        "#authors|works|Albert Camus" => [
          {"name"=>"Albert Camus", "title"=>"L'E'tranger"},
          {"name"=>"Albert Camus", "title"=>"La Peste"}],
        "#authors|works|Marcel Ayme'" => [
          {"name"=>"Marcel Ayme'", "title"=>"Le Passe-muraille"},
          {"name"=>"Marcel Ayme'", "title"=>"Les Contes du chat perche'"}]}

      reader = AdHocTemplate::RecipeManager.new(recipe_source)
      recipe = reader.recipe
      block = recipe['blocks'][1]
      data_file_path = File.expand_path(block['data'])
      csv_data = StringIO.new(@csv_data)
      open_mode = ['rb', block['data_encoding']].join(':')
      allow(reader).to receive(:open).with(data_file_path, open_mode).and_yield(csv_data)
      block_data = reader.prepare_block_data(block)
      expect(block_data).to eq(expected_result)
    end

    it '#load_records reads blocks and merge them' do
      expected_result = {
        "country" => "French",
        "#authors" => [{"name"=>"Albert Camus", "birth_place"=>"Algeria"}, {"name"=>"Marcel Ayme'", "birth_place"=>"France"}],
        "#authors|works|Albert Camus" => [
          {"name"=>"Albert Camus", "title"=>"L'E'tranger"},
          {"name"=>"Albert Camus", "title"=>"La Peste"}],
        "#authors|works|Marcel Ayme'" => [
          {"name"=>"Marcel Ayme'", "title"=>"Le Passe-muraille"},
          {"name"=>"Marcel Ayme'", "title"=>"Les Contes du chat perche'"}]}

      reader = AdHocTemplate::RecipeManager.new(@recipe)
      recipe = reader.recipe
      allow(reader).to receive(:open).with(File.expand_path(recipe['data']), 'rb:BOM|UTF-8').and_yield(StringIO.new(@main_data))
      recipe['blocks'].each do |block|
        data_file_path = File.expand_path(block['data'])
        csv_data = StringIO.new(@csv_data)
        open_mode = ['rb', block['data_encoding']].join(':')
        allow(reader).to receive(:open).with(data_file_path, open_mode).and_yield(StringIO.new(@csv_data))
      end
      main_block = reader.load_records
      expect(main_block).to eq(expected_result)
    end

    it '#load_records may read recipes without iteration blocks' do
      recipe_source = <<RECIPE
---
template: template.html
tag_type: :default
template_encoding: UTF-8
data: main.aht
data_format: 
data_encoding: 
output_file: 
RECIPE

      main_data = <<MAIN_DATA
country: French
century: 20

MAIN_DATA

      expected_result = {
        "country" => "French",
        "century" => "20"
      }

      reader = AdHocTemplate::RecipeManager.new(recipe_source)
      recipe = reader.recipe
      allow(reader).to receive(:open).with(File.expand_path(recipe['data']), 'rb:BOM|UTF-8').and_yield(StringIO.new(main_data))

      main_block = reader.load_records
      expect(main_block).to eq(expected_result)
    end

    it "the result of #load_records can be used as input of DataLoader.parse" do
      reader = AdHocTemplate::RecipeManager.new(@recipe)
      recipe = reader.recipe
      allow(reader).to receive(:open).with(File.expand_path(recipe['data']), 'rb:BOM|UTF-8').and_yield(StringIO.new(@main_data))
      recipe['blocks'].each do |block|
        data_file_path = File.expand_path(block['data'])
        csv_data = StringIO.new(@csv_data)
        open_mode = ['rb', block['data_encoding']].join(':')
        allow(reader).to receive(:open).with(data_file_path, open_mode).and_yield(StringIO.new(@csv_data))
      end

      main_block = reader.load_records
      tree = AdHocTemplate::Parser.parse(@template)
      result = AdHocTemplate::DataLoader.format(tree, main_block)
      expect(result).to eq(@expected_result)
    end

    it "#parse_template parses the template file specified in the recipe" do
      reader = AdHocTemplate::RecipeManager.new(@recipe)
      template_path = File.expand_path(reader.recipe['template'])
      open_mode = 'rb:BOM|UTF-8'
      expect_any_instance_of(AdHocTemplate::RecipeManager).to receive(:open).with(template_path, open_mode).and_yield(StringIO.new(@template))

      reader.parse_template

      expect(reader.template).to eq(@parsed_template)
    end

    it "#update_output_file writes the result into an output file specified in the recipe" do
      reader = AdHocTemplate::RecipeManager.new(@recipe)
      recipe = reader.recipe

      allow_any_instance_of(AdHocTemplate::RecipeManager).to receive(:open).with(File.expand_path(recipe['data']), 'rb:BOM|UTF-8').and_yield(StringIO.new(@main_data))
      recipe['blocks'].each do |block|
        data_file_path = File.expand_path(block['data'])
        csv_data = StringIO.new(@csv_data)
        open_mode = block['data_encoding'] ? ['rb', block['data_encoding']].join(':') : 'rb:BOM|UTF-8'
        expect_any_instance_of(AdHocTemplate::RecipeManager).to receive(:open).with(data_file_path, open_mode).and_yield(StringIO.new(@csv_data))
      end

      template_path = File.expand_path(reader.recipe['template'])
      open_mode = 'rb:BOM|UTF-8'
      output_file_path = File.expand_path(reader.recipe['output_file'])
      output_file = StringIO.new(@template)
      expect_any_instance_of(AdHocTemplate::RecipeManager).to receive(:open).with(template_path, open_mode).and_yield(StringIO.new(@template))
      expect_any_instance_of(AdHocTemplate::RecipeManager).to receive(:open).with(output_file_path, 'wb:UTF-8').and_yield(output_file)

      reader.update_output_file
      expect(output_file.string).to eq(@expected_result)
    end

    describe '#modified_after_last_output?' do
      before do
        recipe_source = File.read('spec/test_data/recipe.yaml')
        @recipe = AdHocTemplate::RecipeManager.new(recipe_source)
        @near_average_time = File.mtime(@recipe.recipe['template'])
        @newest_file_time = @near_average_time + 3600
        @oldest_file_time = @near_average_time - 3600
        @output_path = File.expand_path(@recipe.recipe['output_file'])
      end

      it 'returns true when the output file does not exist' do
        allow(File).to receive(:exist?).with(@output_path).and_return(false)

        expect(@recipe.modified_after_last_output?).to be_truthy
      end

      it 'returns true when the output file is older than the template file' do
        allow(File).to receive(:exist?).with(@output_path).and_return(true)
        allow(File).to receive(:mtime).with(@output_path).and_return(@near_average_time)
        allow(File).to receive(:mtime).with(File.expand_path(@recipe.recipe['template'])).and_return(@newest_file_time)
        @recipe.recipe['blocks'].each do |block|
          allow(File).to receive(:mtime).with(File.expand_path(block['data'])).and_return(@oldest_file_time)
        end

        expect(@recipe.modified_after_last_output?).to be_truthy
      end

      it 'returns true when the output file is older than data files' do
        allow(File).to receive(:exist?).with(@output_path).and_return(true)
        allow(File).to receive(:mtime).with(@output_path).and_return(@near_average_time)
        allow(File).to receive(:mtime).with(File.expand_path(@recipe.recipe['template'])).and_return(@oldest_file_time)
        @recipe.recipe['blocks'].each do |block|
          allow(File).to receive(:mtime).with(File.expand_path(block['data'])).and_return(@newest_file_time)
        end

        expect(@recipe.modified_after_last_output?).to be_truthy
      end

      it 'returns true when RecipeManager#output_file returns nil' do
        recipe_source = <<RECIPE
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
RECIPE

        recipe = AdHocTemplate::RecipeManager.new(recipe_source)

        expect(recipe.modified_after_last_output?).to be_truthy
      end

      it 'returns false when the output file is the newest file' do
        allow(File).to receive(:exist?).with(@output_path).and_return(true)
        allow(File).to receive(:mtime).with(@output_path).and_return(@newest_file_time)
        allow(File).to receive(:mtime).with(File.expand_path(@recipe.recipe['template'])).and_return(@near_average_time)
        @recipe.recipe['blocks'].each do |block|
          allow(File).to receive(:mtime).with(File.expand_path(block['data'])).and_return(@near_average_time)
        end

        expect(@recipe.modified_after_last_output?).to be_falsy
      end
    end
  end
end

