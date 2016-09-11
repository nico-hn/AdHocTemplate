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

    it '.dump raises an exception' do
      parsed_data = AdHocTemplate::RecordReader.read_record(@config_source)
      error_type = AdHocTemplate::RecordReader::CSVReader::NotSupportedError

      expect do
        AdHocTemplate::RecordReader::CSVReader.dump(parsed_data)
      end.to raise_error(error_type)
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
        csv_reader = AdHocTemplate::RecordReader::CSVReader.read_record(@csv_source, tsv: "subconfigs")
        record_reader = AdHocTemplate::RecordReader.read_record(@csv_source, tsv: "subconfigs")

        csv_reader_without_label = AdHocTemplate::RecordReader::CSVReader.read_record(@csv_source, :tsv)
        record_reader_without_label = AdHocTemplate::RecordReader.read_record(@csv_source, :tsv)


        expect(csv_reader).to eq(record_reader)
        expect(csv_reader_without_label).to eq(record_reader_without_label)
      end
    end
  end
end
