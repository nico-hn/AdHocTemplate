#!/usr/bin/env ruby

require 'spec_helper'
require 'ad_hoc_template'

describe AdHocTemplate do
  describe AdHocTemplate::RecordReader do
    it "can read key-value pairs and empty lines at the head should be ignored" do
      data = <<CONFIG

key1: value1
key2: value2
key3: value3


CONFIG

      expect(AdHocTemplate::RecordReader.read_record(data)).to eq({ "key1" => "value1", "key2" => "value2", "key3" => "value3", })
    end

    it "can accept an empty string as its input" do
      expect(AdHocTemplate::RecordReader.read_record('')).to eq({})
    end

    it "can read several header type configurations at once." do
      data = <<CONFIGS
///@#configs

key1-1: value1-1
key1-2: value1-2

key2-1: value2-1
key2-2: value2-2

key3-1: value3-1
key3-2: value3-2

CONFIGS

      expected_config = {
        "#configs" => [
          {"key1-1" => "value1-1", "key1-2" => "value1-2"},
          {"key2-1" => "value2-1", "key2-2" => "value2-2"},
          {"key3-1" => "value3-1", "key3-2" => "value3-2"}
        ]}
      expect(AdHocTemplate::RecordReader.read_record(data)).to eq(expected_config)
    end

    it "can read sets of several header type configurations at once." do
      data = <<CONFIGS
///@#configs

key1-1: value1-1
key1-2: value1-2

key2-1: value2-1
key2-2: value2-2

key3-1: value3-1
key3-2: value3-2

///@#configs2

key1-1: value1-1
key1-2: value1-2

key2-1: value2-1
key2-2: value2-2

key3-1: value3-1
key3-2: value3-2

CONFIGS

      expected_config = {
        "#configs" => [
          {"key1-1" => "value1-1", "key1-2" => "value1-2"},
          {"key2-1" => "value2-1", "key2-2" => "value2-2"},
          {"key3-1" => "value3-1", "key3-2" => "value3-2"}
        ],
        "#configs2" => [
          {"key1-1" => "value1-1", "key1-2" => "value1-2"},
          {"key2-1" => "value2-1", "key2-2" => "value2-2"},
          {"key3-1" => "value3-1", "key3-2" => "value3-2"}
        ]
      }
      expect(AdHocTemplate::RecordReader.read_record(data)).to eq(expected_config)
    end

    it "reads configuration data and turns them into a hash object" do
      data = <<CONFIG
key1: value1
key2: value2
key3: value3

///@block1

the first line of block1
the second line of block1

the second paragraph in block1

///@block2
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

///@#subconfigs

key1-1: value1-1
key1-2: value1-2

key2-1: value2-1
key2-2: value2-2

///@block

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

    it "may contain blocks with comments" do
      data = <<CONFIG
//// comment1 in key-value block

key1: value1
//// comment2 in key-value block
key2: value2
key3: value3
//// comment3 in key-value block

///@#subconfigs

key1-1: value1-1
key1-2: value1-2

key2-1: value2-1
key2-2: value2-2

///@block

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

  describe AdHocTemplate::RecordReader::YAMLReader do
    before do
      @config_source = <<CONFIG
key1: value1
key2: value2
key3: value3

///@#subconfigs

key1-1: value1-1
key1-2: value1-2

key2-1: value2-1
key2-2: value2-2

///@block

the first line of block
the second line of block

the second paragraph in block

CONFIG

      @yaml_source = <<YAML
key1: value1
key2: value2
key3: value3
'#subconfigs':
  - key1-1: value1-1
    key1-2: value1-2
  - key2-1: value2-1
    key2-2: value2-2
block: |
  the first line of block
  the second line of block
  
  the second paragraph in block
YAML

      @yaml_dump = <<YAML
---
key1: value1
key2: value2
key3: value3
"#subconfigs":
- key1-1: value1-1
  key1-2: value1-2
- key2-1: value2-1
  key2-2: value2-2
block: |
  the first line of block
  the second line of block

  the second paragraph in block
YAML
    end

    it 'reads yaml data and turns it into a Ruby object' do
      config = AdHocTemplate::RecordReader.read_record(@config_source)
      yaml = AdHocTemplate::RecordReader::YAMLReader.read_record(@yaml_source)

      expect(yaml).to eq(config)
    end

    it '.read_record is called from RecordReader.read_record if the format of source data is specified' do
      yaml_reader = AdHocTemplate::RecordReader::YAMLReader.read_record(@yaml_source)
      record_reader = AdHocTemplate::RecordReader.read_record(@yaml_source, :yaml)

      expect(yaml_reader).to eq(record_reader)
    end

    it '.dump converts the format of data from default to yaml' do
      yaml = AdHocTemplate::RecordReader::YAMLReader.dump(@config_source)

      expect(yaml).to eq(@yaml_dump)
    end

    it '.dump accepts parsed data too' do
      parsed_data = AdHocTemplate::RecordReader.read_record(@config_source)
      yaml = AdHocTemplate::RecordReader::YAMLReader.dump(parsed_data)

      expect(yaml).to eq(@yaml_dump)
    end

    it 'may contain key-value pairs whose value are not String' do
      yaml_source = <<YAML
---
key1: 1
key2: 2
"#iterate":
  - key3: 3
  - key3: 4
YAML

      template = '<%= key1 %> and <%h key2 %><%#iterate:  <%= key3 %>'
      expected_result = '1 and 2 3 4'

      yaml = AdHocTemplate::RecordReader::YAMLReader.read_record(yaml_source)
      tree = AdHocTemplate::Parser.parse(template)
      tag_formatter = AdHocTemplate::DefaultTagFormatter.new
      result = AdHocTemplate::DataLoader.format(tree, yaml, tag_formatter)

      expect(result).to eq(expected_result)
    end
  end

  describe AdHocTemplate::RecordReader::JSONReader do
    before do
      @config_source = <<CONFIG
key1: value1
key2: value2
key3: value3

///@#subconfigs

key1-1: value1-1
key1-2: value1-2

key2-1: value2-1
key2-2: value2-2

///@block

the first line of block
the second line of block

the second paragraph in block

CONFIG

      @json_source = <<JSON
{
    "key1":"value1",
    "key2":"value2",
    "key3":"value3",
    "#subconfigs":
    [
	{
	    "key1-1":"value1-1",
	    "key1-2":"value1-2"
	},
	{
	    "key2-1":"value2-1",
	    "key2-2":"value2-2"
	}
    ],
    "block":"the first line of block\\nthe second line of block\\n\\nthe second paragraph in block\\n"
}
JSON

      @json_dump = <<JSON
{
  "key1": "value1",
  "key2": "value2",
  "key3": "value3",
  "#subconfigs": [
    {
      "key1-1": "value1-1",
      "key1-2": "value1-2"
    },
    {
      "key2-1": "value2-1",
      "key2-2": "value2-2"
    }
  ],
  "block": "the first line of block\\nthe second line of block\\n\\nthe second paragraph in block\\n"
}
JSON
    end

    it 'reads JSON data and turns it into a Ruby object' do
      config = AdHocTemplate::RecordReader.read_record(@config_source)
      json = AdHocTemplate::RecordReader::JSONReader.read_record(@json_source)

      expect(json).to eq(config)
    end

    it '.read_record is called from RecordReader.read_record if the format of source data is specified' do
      json_reader = AdHocTemplate::RecordReader::JSONReader.read_record(@json_source)
      record_reader = AdHocTemplate::RecordReader.read_record(@json_source, :json)

      expect(json_reader).to eq(record_reader)
    end

    it '.dump converts the format of data from default to json' do
      json = AdHocTemplate::RecordReader::JSONReader.dump(@config_source)

      expect(json).to eq(@json_dump.chomp)
    end

    it '.dump accepts parsed data too' do
      parsed_data = AdHocTemplate::RecordReader.read_record(@config_source)
      json = AdHocTemplate::RecordReader::JSONReader.dump(parsed_data)

      expect(json).to eq(@json_dump.chomp)
    end

    it 'may contain key-value pairs whose value are not String' do
      json_source = <<JSON
{
  "key1": 1,
  "key2": 2,
  "#iterate": [
    {
      "key3": 3
    },
    {
      "key3": 4
    }
  ]
}
JSON

      template = '<%= key1 %> and <%h key2 %><%#iterate:  <%= key3 %>'
      expected_result = '1 and 2 3 4'

      json = AdHocTemplate::RecordReader::JSONReader.read_record(json_source)
      tree = AdHocTemplate::Parser.parse(template)
      tag_formatter = AdHocTemplate::DefaultTagFormatter.new
      result = AdHocTemplate::DataLoader.format(tree, json, tag_formatter)

      expect(result).to eq(expected_result)
    end
  end

  describe AdHocTemplate::RecordReader::CSVReader do
      before do
        @config_source = <<CONFIG
///@#subconfigs

key1: value1-1
key2: value1-2
key3: value1-3

key1: value2-1
key2: value2-2
key3: value2-3

key1: value3-1
key2: value3-2
key3: value3-3

CONFIG

        @csv_incompatible_config_source = <<CONFIG
key: value

///@#subconfigs

key1: value1-1
key2: value1-2
key3: value1-3

key1: value2-1
key2: value2-2
key3: value2-3

key1: value3-1
key2: value3-2
key3: value3-3

CONFIG

      @config_source_without_iteration = <<CONFIG
key1: value1
key2: value2
key3: value3
CONFIG


        @csv_source = <<CSV
key1,key2,key3
value1-1,value1-2,value1-3
value2-1,value2-2,value2-3
value3-1,value3-2,value3-3
CSV

      @tsv_source =<<TSV
key1	key2	key3
value1-1	value1-2	value1-3
value2-1	value2-2	value2-3
value3-1	value3-2	value3-3
TSV
    end

    it '.dump can convert data in default format to CSV when the data have just one record' do
      expected_csv = <<CSV
key1,key2,key3
value1,value2,value3
CSV
      parsed_data = AdHocTemplate::RecordReader.read_record(@config_source_without_iteration)
      csv = AdHocTemplate::RecordReader::CSVReader.dump(parsed_data)

      expect(csv).to eq(expected_csv)
    end

    it '.dump can convert data in default format to CSV when the data consist of just one iteration block' do
      parsed_data = AdHocTemplate::RecordReader.read_record(@config_source)
      csv = AdHocTemplate::RecordReader::CSVReader.dump(parsed_data)

      expect(csv).to eq(@csv_source)
    end

    it '.dump may return CSV data that contain empty fields' do
        config_source = <<CONFIG
///@#subconfigs

key1: value1-1
key3: value1-3

key1: value2-1
key2: value2-2
key3: value2-3

key3: value3-3

CONFIG

      expected_csv = <<CSV
key1,key2,key3
value1-1,,value1-3
value2-1,value2-2,value2-3
,,value3-3
CSV

      parsed_data = AdHocTemplate::RecordReader.read_record(config_source)
      csv = AdHocTemplate::RecordReader::CSVReader.dump(parsed_data)

      expect(csv).to eq(expected_csv)
    end

    it '.dump raises an exception when the structure of given data is too complex' do
      parsed_data = AdHocTemplate::RecordReader.read_record(@csv_incompatible_config_source)
      error_type = AdHocTemplate::RecordReader::CSVReader::NotSupportedError

      expect do
        AdHocTemplate::RecordReader::CSVReader.dump(parsed_data)
      end.to raise_error(error_type)
    end

    it '.dump can generate TSV data too' do
      col_sep = AdHocTemplate::RecordReader::CSVReader::COL_SEP[:tsv]
      parsed_data = AdHocTemplate::RecordReader.read_record(@config_source)
      tsv = AdHocTemplate::RecordReader::CSVReader.dump(parsed_data, col_sep)

      expect(tsv).to eq(@tsv_source)
    end

    it 'TSV.dump is an alias of CSV.dump except for its default col_sep value' do
      col_sep = AdHocTemplate::RecordReader::CSVReader::COL_SEP[:tsv]
      parsed_data = AdHocTemplate::RecordReader.read_record(@config_source)
      tsv_by_csv_reader = AdHocTemplate::RecordReader::CSVReader.dump(parsed_data, col_sep)
      tsv = AdHocTemplate::RecordReader::TSVReader.dump(parsed_data)

      expect(tsv).to eq(tsv_by_csv_reader)
    end

    it 'reads CSV data and turns it into a Ruby object' do
      config = AdHocTemplate::RecordReader.read_record(@config_source)
      csv = AdHocTemplate::RecordReader::CSVReader.read_record(@csv_source, "subconfigs")

      expect(csv).to eq(config)
    end

    it '.read_record is called from RecordReader.read_record if the format of source data is specified' do
      csv_reader = AdHocTemplate::RecordReader::CSVReader.read_record(@csv_source, "subconfigs")
      record_reader = AdHocTemplate::RecordReader.read_record(@csv_source, csv: "subconfigs")

      csv_reader_without_label = AdHocTemplate::RecordReader::CSVReader.read_record(@csv_source)
      record_reader_without_label = AdHocTemplate::RecordReader.read_record(@csv_source, :csv)


      expect(csv_reader).to eq(record_reader)
      expect(csv_reader_without_label).to eq(record_reader_without_label)
    end

    describe "TSV" do
      it 'reads TSV data and turns it into a Ruby object' do
        config = AdHocTemplate::RecordReader.read_record(@config_source)
        tsv = AdHocTemplate::RecordReader::CSVReader.read_record(@tsv_source, tsv: "subconfigs")

        expect(tsv).to eq(config)
      end

      it '.read_record is called from RecordReader.read_record if the format of source data is specified' do
        csv_reader = AdHocTemplate::RecordReader::CSVReader.read_record(@tsv_source, tsv: "subconfigs")
        record_reader = AdHocTemplate::RecordReader.read_record(@tsv_source, tsv: "subconfigs")

        csv_reader_without_label = AdHocTemplate::RecordReader::CSVReader.read_record(@tsv_source, :tsv)
        record_reader_without_label = AdHocTemplate::RecordReader.read_record(@tsv_source, :tsv)


        expect(csv_reader).to eq(record_reader)
        expect(csv_reader_without_label).to eq(record_reader_without_label)
      end

      it 'TSV.read_record is an alias of CSV.dump except for its default col_sep value' do
        csv_reader = AdHocTemplate::RecordReader::CSVReader.read_record(@tsv_source, tsv: "subconfigs")
        tsv_reader = AdHocTemplate::RecordReader::TSVReader.read_record(@tsv_source, "subconfigs")

        expect(tsv_reader).to eq(csv_reader)
      end
    end
  end

  describe AdHocTemplate::RecordReader::DefaultFormReader do
    before do
      @config_source = <<CONFIG
key1: value1
key2: value2
key3: value3

///@#subconfigs

key1-1: value1-1
key1-2: value1-2

key2-1: value2-1
key2-2: value2-2

///@block

the first line of block
the second line of block

the second paragraph in block

CONFIG

      @yaml_source = <<YAML
key1: value1
key2: value2
key3: value3
'#subconfigs':
  - key1-1: value1-1
    key1-2: value1-2
  - key2-1: value2-1
    key2-2: value2-2
block: |
  the first line of block
  the second line of block
  
  the second paragraph in block
YAML
    end

    it ',dump accepts non-empty data' do
      parsed_data = AdHocTemplate::RecordReader::YAMLReader.read_record(@yaml_source)
      dump_data = AdHocTemplate::RecordReader::DefaultFormReader.dump(parsed_data)
      expected_data = @config_source.sub(/(#{$/}+)\Z/, $/)

      expect(dump_data).to eq(expected_data)
    end

    describe 'private methods' do
      it '.categorize_keys devide keys into 3 groups' do
        parsed_data = AdHocTemplate::RecordReader::YAMLReader.read_record(@yaml_source)
        iteration_keys, key_value_keys, block_keys = AdHocTemplate::RecordReader::DefaultFormReader.send :categorize_keys, parsed_data

        expect(iteration_keys).to eq(%w(#subconfigs))
        expect(key_value_keys).to eq(%w(key1 key2 key3))
        expect(block_keys).to eq (%w(block))
      end

      it '.format_key_value_pairs returns a YAML like key-value pairs' do
        expected_result = <<RESULT
key1: value1
key2: value2
key3: value3
RESULT

        parsed_data = AdHocTemplate::RecordReader::YAMLReader.read_record(@yaml_source)
        iteration_keys, key_value_keys, block_keys = AdHocTemplate::RecordReader::DefaultFormReader.send :categorize_keys, parsed_data
        format_result = AdHocTemplate::RecordReader::DefaultFormReader.send :format_key_value_pairs, key_value_keys, parsed_data

        expect(format_result).to eq(expected_result)
      end

      it '.format_key_value_block returns a header with label and multi-line value' do
        expected_result = <<RESULT
///@block

the first line of block
the second line of block

the second paragraph in block
RESULT

        parsed_data = AdHocTemplate::RecordReader::YAMLReader.read_record(@yaml_source)
        iteration_keys, key_value_keys, block_keys = AdHocTemplate::RecordReader::DefaultFormReader.send :categorize_keys, parsed_data
        format_result = AdHocTemplate::RecordReader::DefaultFormReader.send :format_key_value_block, block_keys, parsed_data

        expect(format_result).to eq(expected_result)
      end

      it '.format_iteration_block returns a header and sub-records YAML like key-value pairs' do
        expected_result = <<RESULT
///@#subconfigs

key1-1: value1-1
key1-2: value1-2

key2-1: value2-1
key2-2: value2-2
RESULT

        parsed_data = AdHocTemplate::RecordReader::YAMLReader.read_record(@yaml_source)
        iteration_keys, key_value_keys, block_keys = AdHocTemplate::RecordReader::DefaultFormReader.send :categorize_keys, parsed_data
        format_result = AdHocTemplate::RecordReader::DefaultFormReader.send :format_iteration_block, iteration_keys, parsed_data

        expect(format_result).to eq(expected_result)
      end
    end
  end
end
