require 'spec_helper'
require 'ad_hoc_template'

describe AdHocTemplate do
  it 'should have a version number' do
    AdHocTemplate::VERSION.should_not be_nil
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
  end

  describe AdHocTemplate::ConfigurationReader do
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
      expect(AdHocTemplate::ConfigurationReader.read_config(data)).to eq(expected_config)
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
      config = AdHocTemplate::ConfigurationReader.read_config(config_data)
      expect(AdHocTemplate::Converter.new(config).format(tree)).to eq("a test string with tags (value1 and value2) in it")
    end
  end
end
