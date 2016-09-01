require 'spec_helper'
require 'ad_hoc_template'

describe AdHocTemplate do

  it 'should have a version number' do
    expect(AdHocTemplate::VERSION).to_not be_nil
  end

  describe AdHocTemplate::DataLoader do
    before do
      @template_with_an_iteration_block = <<TEMPLATE
a test string with tags (<%= key1 %> and <%= key2 %>) in it

<%#iteration_block
the value of sub_key1 is <%= sub_key1 %>
the value of sub_key2 is <%= sub_key2 %>

#%>
<%= block %>
TEMPLATE

      @config_data_with_an_iteration_block = <<CONFIG
key1: value1
key2: value2
key3: value3

//@#iteration_block

sub_key1: value1-1
sub_key2: value1-2

sub_key1: value2-1
sub_key2: value2-2

//@block

the first line of block
the second line of block

the second paragraph in block

CONFIG

      @expected_result_with_an_iteration_block = <<RESULT
a test string with tags (value1 and value2) in it

the value of sub_key1 is value1-1
the value of sub_key2 is value1-2

the value of sub_key1 is value2-1
the value of sub_key2 is value2-2

the first line of block
the second line of block

the second paragraph in block

RESULT
    end

    it "returns the result of conversion." do
      template = "a test string with tags (<%= key1 %> and <%= key2 %>) in it"
      config_data = <<CONFIG
key1: value1
key2: value2
CONFIG

      tree = AdHocTemplate::Parser.parse(template)
      config = AdHocTemplate::RecordReader.read_record(config_data)
      expect(AdHocTemplate::DataLoader.new(config).format(tree)).to eq("a test string with tags (value1 and value2) in it")
    end

    it "accepts a template with an iteration block and evaluate repeatedly the block" do
      template = @template_with_an_iteration_block
      config_data = @config_data_with_an_iteration_block
      expected_result = @expected_result_with_an_iteration_block

      tree = AdHocTemplate::Parser.parse(template)
      config = AdHocTemplate::RecordReader.read_record(config_data)
      expect(AdHocTemplate::DataLoader.new(config).format(tree)).to eq(expected_result)
    end

    it "may contains iteration blocks without key label." do
      template = <<TEMPLATE
a test string with tags (<%= key1 %> and <%= key2 %>) in it

<%#
the value of key1 is <%= key1 %>
the value of key2 is <%= key2 %>

#%>
<%#
the value of key2 is <%= non-existent-key %>
the value of key2 is <%= key-without-value %>
#%>
<%# the value of key2 is <%= non-existent-key %> #%>
<%= block %>
TEMPLATE

      config_data = <<CONFIG
key1: value1
key2: value2
key3: value3
key-without-value: 

//@block

the first line of block
the second line of block

the second paragraph in block

CONFIG

expected_result = <<RESULT
a test string with tags (value1 and value2) in it

the value of key1 is value1
the value of key2 is value2

the first line of block
the second line of block

the second paragraph in block

RESULT

      tree = AdHocTemplate::Parser.parse(template)
      config = AdHocTemplate::RecordReader.read_record(config_data)
      expect(AdHocTemplate::DataLoader.new(config).format(tree)).to eq(expected_result)
    end

    it "offers .format method for convenience" do
      template = @template_with_an_iteration_block
      config_data = @config_data_with_an_iteration_block
      expected_result = @expected_result_with_an_iteration_block

      tree = AdHocTemplate::Parser.parse(template)
      config = AdHocTemplate::RecordReader.read_record(config_data)
      tag_formatter = AdHocTemplate::DefaultTagFormatter.new
      expect(AdHocTemplate::DataLoader.format(tree, config, tag_formatter)).to eq(expected_result)
    end

    it("should not add a newline at the head of IterationTagNode when the type of the node is not specified") do
      template = <<TEMPLATE
a test string with tags
<%#iteration_block
the value of sub_key1 is <%= sub_key1 %>
<%#
  the value of sub_key2 is <%= sub_key2 %>
#%>

#%>
<%= block %>
TEMPLATE

      config_data = <<CONFIG
//@#iteration_block

sub_key1: value1-1
sub_key2: value1-2

sub_key1: value2-1

//@block

the first line of block
CONFIG

expected_result = <<RESULT
a test string with tags
the value of sub_key1 is value1-1
  the value of sub_key2 is value1-2

the value of sub_key1 is value2-1

the first line of block

RESULT
      tree = AdHocTemplate::Parser.parse(template)
      config = AdHocTemplate::RecordReader.read_record(config_data)
      tag_formatter = AdHocTemplate::DefaultTagFormatter.new
      expect(AdHocTemplate::DataLoader.format(tree, config, tag_formatter)).to eq(expected_result)
    end
  end

  it 'can convert &"<> into character entities' do
    result = AdHocTemplate.convert('characters: &, ", < and >',
                                   'a string with characters (<%h characters %>) that should be represented as character entities.')
    expect(result).to eq('a string with characters (&amp;, &quot;, &lt; and &gt;) that should be represented as character entities.')
  end
end
