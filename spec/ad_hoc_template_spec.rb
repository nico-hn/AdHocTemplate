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

///@#iteration_block

sub_key1: value1-1
sub_key2: value1-2

sub_key1: value2-1
sub_key2: value2-2

///@block

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

///@block

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
///@#iteration_block

sub_key1: value1-1
sub_key2: value1-2

sub_key1: value2-1

///@block

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

    describe "iteration block" do
      before do
        @template =<<TEMPLATE
The first line in the main part

<%#
The first line in the iteration part

<%#iteration_block
The value of key1 is <%= key1 %>
#%>

#%>
TEMPLATE

        @template_with_nested_iteration_tag =<<TEMPLATE
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
TEMPLATE

        @expected_result_when_data_provided =<<RESULT
The first line in the main part

The first line in the iteration part

The value of key1 is value1
The value of key1 is value1

RESULT

        @expected_result_for_nested_iteration_tag_when_data_provided =<<RESULT
The first line in the main part

The first line in the iteration part

Key value: value
Optinal values:  optinal value1 and [optional2] are in the record.

The value of key1 is value1
The value of key1 is value1
The value of optional key2 is value2

RESULT
      end

      describe "with data in default format" do
        it "should not ignore the content of an iteration block when some data are provided" do
          config_data = <<CONFIG
///@#iteration_block

key1: value1

key1: value1
CONFIG

          expected_result = @expected_result_when_data_provided

          tree = AdHocTemplate::Parser.parse(@template)
          config = AdHocTemplate::RecordReader.read_record(config_data)
          tag_formatter = AdHocTemplate::DefaultTagFormatter.new

          expect(AdHocTemplate::DataLoader.format(tree, config, tag_formatter)).to eq(expected_result)
        end

        it "should ignore the content of an iteration block if no thing is provided" do
          config_data = <<CONFIG
///@#iteration_block

CONFIG

          expected_result =<<RESULT
The first line in the main part

RESULT

          tree = AdHocTemplate::Parser.parse(@template)
          config = AdHocTemplate::RecordReader.read_record(config_data)
          tag_formatter = AdHocTemplate::DefaultTagFormatter.new

          expect(AdHocTemplate::DataLoader.format(tree, config, tag_formatter)).to eq(expected_result)
        end

        it "may contain nested iteration blocks" do
          config_data = <<CONFIG
key: value
optional1: optinal value1

///@#iteration_block

key1: value1

key1: value1
key2: value2
CONFIG

          expected_result = @expected_result_for_nested_iteration_tag_when_data_provided

          tree = AdHocTemplate::Parser.parse(@template_with_nested_iteration_tag)
          config = AdHocTemplate::RecordReader.read_record(config_data)
          tag_formatter = AdHocTemplate::DefaultTagFormatter.new

          expect(AdHocTemplate::DataLoader.format(tree, config, tag_formatter)).to eq(expected_result)
        end

        it "should ignore nested iteration blocks unless data are provided" do
          config_data = <<CONFIG
key: 
optional1: 

///@#iteration_block

key1: 

key1: 
key2: 
CONFIG

          expected_result =<<RESULT
The first line in the main part

RESULT

          tree = AdHocTemplate::Parser.parse(@template_with_nested_iteration_tag)
          config = AdHocTemplate::RecordReader.read_record(config_data)
          tag_formatter = AdHocTemplate::DefaultTagFormatter.new

          expect(AdHocTemplate::DataLoader.format(tree, config, tag_formatter)).to eq(expected_result)
        end
      end

      describe "with data in YAML format" do
        it "should not ignore the content of an iteration block when some data are provided" do
          config_data = <<CONFIG
'#iteration_block':
  - key1: value1
  - key1: value1
CONFIG

          expected_result = @expected_result_when_data_provided

          tree = AdHocTemplate::Parser.parse(@template)
          config = AdHocTemplate::RecordReader.read_record(config_data, :yaml)
          tag_formatter = AdHocTemplate::DefaultTagFormatter.new

          expect(AdHocTemplate::DataLoader.format(tree, config, tag_formatter)).to eq(expected_result)
        end

        it "should ignore the content of an iteration block if no thing is provided" do
          config_data = <<CONFIG
'#iteration_block':

CONFIG

          expected_result =<<RESULT
The first line in the main part

RESULT

          tree = AdHocTemplate::Parser.parse(@template)
          config = AdHocTemplate::RecordReader.read_record(config_data, :yaml)
          tag_formatter = AdHocTemplate::DefaultTagFormatter.new

          expect(AdHocTemplate::DataLoader.format(tree, config, tag_formatter)).to eq(expected_result)
        end

        it "may contain nested iteration blocks" do
          config_data = <<CONFIG
key: value
optional1: optinal value1
'#iteration_block':
  - key1: value1
  - key1: value1
    key2: value2
CONFIG

          expected_result = @expected_result_for_nested_iteration_tag_when_data_provided

          tree = AdHocTemplate::Parser.parse(@template_with_nested_iteration_tag)
          config = AdHocTemplate::RecordReader.read_record(config_data, :yaml)
          tag_formatter = AdHocTemplate::DefaultTagFormatter.new

          expect(AdHocTemplate::DataLoader.format(tree, config, tag_formatter)).to eq(expected_result)
        end

        it "should ignore nested iteration blocks unless data are provided" do
          config_data = <<CONFIG
key:
optional1:
'#iteration_block':
  - key1:
  - key1:
    key2:
CONFIG

          expected_result =<<RESULT
The first line in the main part

RESULT

          tree = AdHocTemplate::Parser.parse(@template_with_nested_iteration_tag)
          config = AdHocTemplate::RecordReader.read_record(config_data, :yaml)
          tag_formatter = AdHocTemplate::DefaultTagFormatter.new

          expect(AdHocTemplate::DataLoader.format(tree, config, tag_formatter)).to eq(expected_result)
        end
      end
    end

    describe 'fallback block' do
      before do
        @template = <<TEMPLATE
main start

<%#
<%* content in fallback tag <%= item_in_fallback %> fallback end *%>
optional content
<%#iterations
in iteration tag <%= item %> #%> iteration part end
#%>

main end
TEMPLATE
        @data = <<DATA
item_in_fallback: ITEM_IN_FALLBACK

///@#iterations

item: ITEM_1

item: ITEM_2
DATA
      end

      it 'should be ignored when tags can be filled with data' do
        expected_result = <<RESULT
main start


optional content
in iteration tag ITEM_1 in iteration tag ITEM_2  iteration part end

main end
RESULT
        tree = AdHocTemplate::Parser.parse(@template)
        data = AdHocTemplate::RecordReader.read_record(@data)
        tag_formatter = AdHocTemplate::DefaultTagFormatter.new

        result = AdHocTemplate::DataLoader.format(tree, data, tag_formatter)

        expect(result).to eq(expected_result)
      end
    end
  end

  it 'can convert &"<> into character entities' do
    result = AdHocTemplate.render('characters: &, ", < and >',
                                   'a string with characters (<%h characters %>) that should be represented as character entities.')
    expect(result).to eq('a string with characters (&amp;, &quot;, &lt; and &gt;) that should be represented as character entities.')
  end
end
