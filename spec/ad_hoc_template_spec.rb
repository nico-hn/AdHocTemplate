require 'spec_helper'
require 'ad_hoc_template'

describe AdHocTemplate do
  it 'should have a version number' do
    expect(AdHocTemplate::VERSION).to_not be_nil
  end

  describe AdHocTemplate::Parser do
    it "returns a tree of TagNode and Leaf" do
      expect(AdHocTemplate::Parser.parse("a test string with tags (<% the first tag %> and <% the second tag %>) in it")).to eq([["a test string with tags ("],
                                                                                                                                 [[" the first tag "]],
                                                                                                                                 [" and "],
                                                                                                                                 [[" the second tag "]],
                                                                                                                                 [") in it"]])
    end

    it "allows to have a nested tag" do
      expect(AdHocTemplate::Parser.parse("a test string with a nested tag; <% an outer tag and <% an inner tag %> %>")).to eq([["a test string with a nested tag; "],
                                                                                                                                [[" an outer tag and "],
                                                                                                                                 [[" an inner tag "]],
                                                                                                                                 [" "]]])
    end

    it "may have iteration tags." do
      tree = AdHocTemplate::Parser.parse("a test string with a nested tag: <%# an iteration tag and <% an inner tag %> #%> and <% another tag %>")
      expect(tree).to eq([["a test string with a nested tag: "],
                          [[" an iteration tag and "],
                           [[" an inner tag "]],
                           [" "]],
                          [" and "],
                         [[" another tag "]]])
      expect(tree[1]).to be_a_kind_of(AdHocTemplate::Parser::IterationTagNode)
    end
  end

  describe AdHocTemplate::RecordReader do
    it "can read several header type configurations at once." do
      data = <<CONFIGS

key1-1: value1-1
key1-2: value1-2

key2-1: value2-1
key2-2: value2-2

key3-1: value3-1
key3-2: value3-2

CONFIGS

config = {}
AdHocTemplate::RecordReader.read_iteration_block(data.each_line.to_a, config, "#configs")
      expect(config).to eq({"#configs"=>[{"key1-1"=>"value1-1", "key1-2"=>"value1-2"},
                                         {"key2-1"=>"value2-1", "key2-2"=>"value2-2"},
                                         {"key3-1"=>"value3-1", "key3-2"=>"value3-2"}]})
    end

    it "reads configuration data and turns them into a hash object" do
      data = <<CONFIG
key1: value1
key2: value2
key3: value3

//@block1

the first line of block1
the second line of block1

the second paragraph in block1

//@block2
the first line of block2
the second line of block2

the second paragraph of block2
CONFIG

expected_config = {
        "key1" => "value1",
        "key2" => "value2",
        "key3" => "value3",
        "block1" => "the first line of block1\nthe second line of block1\n\nthe second paragraph in block1\n",
        "block2" => "the first line of block2\nthe second line of block2\n\nthe second paragraph of block2\n"
      }
      expect(AdHocTemplate::RecordReader.read_record(data)).to eq(expected_config)
    end

    it "can read configuration data with 3 different kind of sections" do
      data = <<CONFIG
key1: value1
key2: value2
key3: value3

//@#subconfigs

key1-1: value1-1
key1-2: value1-2

key2-1: value2-1
key2-2: value2-2

//@block

the first line of block
the second line of block

the second paragraph in block

CONFIG

expected_config = {
        "key1" => "value1",
        "key2" => "value2",
        "key3" => "value3",
        "#subconfigs" => [{"key1-1"=>"value1-1", "key1-2"=>"value1-2"}, {"key2-1"=>"value2-1", "key2-2"=>"value2-2"}],
        "block" => "the first line of block\nthe second line of block\n\nthe second paragraph in block\n"
      }
      expect(AdHocTemplate::RecordReader.read_record(data)).to eq(expected_config)
    end
  end

  describe AdHocTemplate::RecordReader::Reader do
    it "can read key-value pairs" do
      data = <<CONFIG

key1: value1
key2: value2
key3: value3


CONFIG

      lines = data.each_line.to_a
      expect(AdHocTemplate::RecordReader::Reader.read_record(lines)).to eq({ "key1" => "value1", "key2" => "value2", "key3" => "value3", })
    end

    it "reads configuration data and turns them into a hash object" do
      data = <<CONFIG
key1: value1
key2: value2
key3: value3

//@block1

the first line of block1
the second line of block1

the second paragraph in block1

//@block2
the first line of block2
the second line of block2

the second paragraph of block2
CONFIG

expected_config = {
        "key1" => "value1",
        "key2" => "value2",
        "key3" => "value3",
        "block1" => "the first line of block1\nthe second line of block1\n\nthe second paragraph in block1\n",
        "block2" => "the first line of block2\nthe second line of block2\n\nthe second paragraph of block2\n"
      }

      lines = data.each_line.to_a
      expect(AdHocTemplate::RecordReader::Reader.read_record(lines)).to eq(expected_config)
    end
  end

  describe AdHocTemplate::Converter do
    it "returns the result of conversion." do
      template = "a test string with tags (<%= key1 %> and <%= key2 %>) in it"
      config_data = <<CONFIG
key1: value1
key2: value2
CONFIG

      tree = AdHocTemplate::Parser.parse(template)
      config = AdHocTemplate::RecordReader.read_record(config_data)
      expect(AdHocTemplate::Converter.new(config).format(tree)).to eq("a test string with tags (value1 and value2) in it")
    end

    it "accepts a template with an iteration block and evaluate repeatedly the block" do
      template = <<TEMPLATE
a test string with tags (<%= key1 %> and <%= key2 %>) in it

<%#iteration_block
the value of sub_key1 is <%= sub_key1 %>
the value of sub_key2 is <%= sub_key2 %>

#%>
<%= block %>
TEMPLATE

      config_data = <<CONFIG
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

expected_result = <<RESULT
a test string with tags (value1 and value2) in it

the value of sub_key1 is value1-1
the value of sub_key2 is value1-2

the value of sub_key1 is value2-1
the value of sub_key2 is value2-2


the first line of block
the second line of block

the second paragraph in block

RESULT
      tree = AdHocTemplate::Parser.parse(template)
      config = AdHocTemplate::RecordReader.read_record(config_data)
      expect(AdHocTemplate::Converter.new(config).format(tree)).to eq(expected_result)
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
      expect(AdHocTemplate::Converter.new(config).format(tree)).to eq(expected_result)
    end

    it 'can convert &"<> into character entities' do
      result = AdHocTemplate::Converter.convert('characters: &, ", < and >',
                                       'a string with characters (<%h characters %>) that should be represented as character entities.')
      expect(result).to eq('a string with characters (&amp;, &quot;, &lt; and &gt;) that should be represented as character entities.')
    end
  end
end
