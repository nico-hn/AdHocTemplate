#!/usr/bin/env ruby

require 'spec_helper'
require 'ad_hoc_template'

describe AdHocTemplate do
  describe AdHocTemplate::EntryFormatGenerator::LabelChecker do
    before do
      @template = <<TEMPLATE
The first line in the main part

<%#
The first line in the iteration part

Key value: <%= key %>
Optinal values: <%# <%= optional1 %> and <%= optional2 %> are in the record.
#%>

<%#iteration_block
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

    it 'collects tag labels from a parsed template' do
      tree = AdHocTemplate::Parser.parse(@template)
      label_checker = AdHocTemplate::EntryFormatGenerator::LabelChecker.new
      tree.accept(label_checker)
      labels = label_checker.labels
      expect(labels).to eq(@expected_labels_as_ruby_objects)
    end

    it '.extract_labels collects tag labels from a parsed template' do
      tree = AdHocTemplate::Parser.parse(@template)
      labels = AdHocTemplate::EntryFormatGenerator.extract_labels(tree)

      expect(labels).to eq(@expected_labels_as_ruby_objects)
    end
  end
end
