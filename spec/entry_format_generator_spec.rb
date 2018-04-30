#!/usr/bin/env ruby

require 'spec_helper'
require 'ad_hoc_template'
require 'stringio'

describe AdHocTemplate do
  describe AdHocTemplate::EntryFormatGenerator do
    before do
      @template = <<TEMPLATE
The first line in the main part

<%#
The first line in the iteration part

Key value: <%= key %>
Optinal values: <%# <%= optional1 %> and <%= optional2 %> are in the record.
#%>

<%#iteration_block:
The value of key1 is <%= key1 %>
<%#
The value of optional key2 is <%= key2 %>
#%>
#%>

#%>

<%= block %>
TEMPLATE

      @expected_labels_as_ruby_objects = {
        "key" => nil,
        "optional1" => nil,
        "optional2" => nil,
        "#iteration_block" => [{
            "key1" => nil,
            "key2" => nil
          }],
        "block" => nil}
    end

    describe AdHocTemplate::EntryFormatGenerator::LabelChecker do
      it 'collects tag labels from a parsed template' do
        tree = AdHocTemplate::Parser.parse(@template)
        label_checker = AdHocTemplate::EntryFormatGenerator::LabelChecker.new
        tree.accept(label_checker)
        labels = label_checker.labels
        expect(labels).to eq(@expected_labels_as_ruby_objects)
      end
    end

    it '.extract_form collects tag labels from a parsed template' do
      expected_labels_in_default_format = <<YAML
key: 
optional1: 
optional2: 
block: 

///@#iteration_block

key1: 
key2: 
YAML

      tree = AdHocTemplate::Parser.parse(@template)
      labels = AdHocTemplate::EntryFormatGenerator.extract_form(tree)

      expect(labels).to eq(expected_labels_in_default_format)
    end

    it '.extract_form should ignore fallback tags if they do not any contain value tag' do
      template = <<TEMPLATE
main start
<%#
optional start <%* fallback part *%> <%= var1 %>
<%#iteration: <%= var2 %> #%>
#%>
<%= var3 %>

main end
TEMPLATE

      expected = <<EXPECTED
var1: 
var3: 

///@#iteration

var2: 
EXPECTED

      tree = AdHocTemplate::Parser.parse(template)
      labels = AdHocTemplate::EntryFormatGenerator.extract_form(tree)

      expect(labels).to eq(expected)
    end

    it '.extract_form should collect labels in fallback tags' do
      template = <<TEMPLATE
main start
<%#
optional start <%* fallback <%= fallback_var1 %> and <%= fallback_var2 %> *%> <%= var1 %>
<%#iteration: <%= var2 %> #%>
#%>
<%= var3 %>

main end
TEMPLATE

      expected = <<EXPECTED
fallback_var1: 
fallback_var2: 
var1: 
var3: 

///@#iteration

var2: 
EXPECTED

      tree = AdHocTemplate::Parser.parse(template)
      labels = AdHocTemplate::EntryFormatGenerator.extract_form(tree)

      expect(labels).to eq(expected)
    end

    it '.extract_form accepts :yaml as its second argument' do
      expected_labels_in_yaml = <<YAML
---
key: 
optional1: 
optional2: 
"#iteration_block":
- key1: 
  key2: 
block: 
YAML

      tree = AdHocTemplate::Parser.parse(@template)
      labels = AdHocTemplate::EntryFormatGenerator.extract_form(tree, :yaml)

      expect(labels).to eq(expected_labels_in_yaml)
    end

    it '.extract_form accepts :json as its second argument' do
      expected_labels_in_json = <<JSON
{
  "key":null,
  "optional1":null,
  "optional2":null,
  "#iteration_block":[{
    "key1":null,
    "key2":null
  }],
  "block":null
}
JSON

      tree = AdHocTemplate::Parser.parse(@template)
      labels = AdHocTemplate::EntryFormatGenerator.extract_form(tree, :json)

      expect(JSON.parse(labels)).to eq(JSON.parse(expected_labels_in_json))
    end

    it '.extract_form should extract labels from nested iteration tags' do
        template =<<TEMPLATE
<%#authors:
Name: <%= name %>
Birthplace: <%= birthplace %>
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

      expected_result =<<RESULT

///@#authors

name: 
birthplace: 

///@#authors|works|name

title: 

///@#authors|bio|name

birth_date: 
RESULT

      tree = AdHocTemplate::Parser.parse(template)
      labels = AdHocTemplate::EntryFormatGenerator.extract_form(tree)

      expect(labels).to eq(expected_result)
    end

    it '.extract_iteration_labels collects iteration labels in a template' do
              template =<<TEMPLATE
<%#authors:
Name: <%= name %>
Birthplace: <%= birthplace %>
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

      tree = AdHocTemplate::Parser.parse(template)
      labels = AdHocTemplate::EntryFormatGenerator.extract_iteration_labels(tree)

      expect(labels).to eq(["#authors", "#authors|works|name", "#authors|bio|name"])
    end

    it '.extract_recipe generates a recipe entry for a given template' do
      template =<<TEMPLATE
<%#authors:
Name: <%= name %>
Birthplace: <%= birthplace %>
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

      expected_recipe = <<RECIPE
---
template: template.html
tag_type: :default
template_encoding: UTF-8
data: 
data_format: 
data_encoding: 
output_file: 
blocks:
- label: "#authors"
  data: 
  data_format: 
  data_encoding: 
- label: "#authors|works|name"
  data: 
  data_format: 
  data_encoding: 
- label: "#authors|bio|name"
  data: 
  data_format: 
  data_encoding: 
RECIPE

      recipe = AdHocTemplate::EntryFormatGenerator.extract_recipe(template, 'template.html')
      expect(recipe).to eq(expected_recipe)
    end

    it '.extract_recipes_from_template_files' do
      recipe_entry = <<RECIPE
---
template: template1.html
tag_type: :default
template_encoding: UTF-8
data: 
data_format: 
data_encoding: 
output_file: 
blocks:
- label: "#iteration_block"
  data: 
  data_format: 
  data_encoding: 
RECIPE
      recipe_entry2 = recipe_entry.sub(/template1\.html/, 'template2.html')

      template_names = %w(template1.html template2.html)
      template_names.each do |template_name|
        allow(AdHocTemplate::EntryFormatGenerator).to receive(:open).with(File.expand_path(template_name), 'rb:BOM|UTF-8').and_yield(StringIO.new(@template))
      end

      result = AdHocTemplate::EntryFormatGenerator.extract_recipes_from_template_files(template_names)
      expect(result).to eq(recipe_entry + recipe_entry2)
    end
  end
end
