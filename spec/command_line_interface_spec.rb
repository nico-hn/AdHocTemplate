#!/usr/bin/env ruby

require 'shellwords'
require 'stringio'
require 'spec_helper'
require 'ad_hoc_template'
require 'ad_hoc_template/command_line_interface'

describe AdHocTemplate do
  describe AdHocTemplate::CommandLineInterface do
    before do
      @template_in_default_format = <<TEMPLATE
a test string with tags (<%= key1 %> and <%= key2 %>) in it

<%#iteration_block
the value of sub_key1 is <%= sub_key1 %>
the value of sub_key2 is <%= sub_key2 %>

#%>
<%= block %>
TEMPLATE

      @record_in_default_format = <<CONFIG
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

      @expected_result = <<RESULT
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

    it "can set the input/output encoding" do
      command_line_interface = AdHocTemplate::CommandLineInterface.new
      command_line_interface.set_encoding("UTF-8:Shift_JIS")
      expect(Encoding.default_external.names).to include("UTF-8")
      expect(Encoding.default_internal.names).to include("Shift_JIS")
    end

    it "accepts an internal only argument" do
      command_line_interface = AdHocTemplate::CommandLineInterface.new
      command_line_interface.set_encoding(":UTF-8")
      expect(Encoding.default_internal.names).to include("UTF-8")
    end

    it "accepts also an external only argument" do
      command_line_interface = AdHocTemplate::CommandLineInterface.new
      command_line_interface.set_encoding("Shift_JIS")
      expect(Encoding.default_external.names).to include("Shift_JIS")
      command_line_interface.set_encoding("UTF-8:")
      expect(Encoding.default_external.names).to include("UTF-8")
    end

    it "can set the internal/external encoding from the command line" do
      command_line_interface = AdHocTemplate::CommandLineInterface.new
      set_argv("-E UTF-8:Shift_JIS")
      command_line_interface.parse_command_line_options
      expect(Encoding.default_external.names).to include("UTF-8")
      expect(Encoding.default_internal.names).to include("Shift_JIS")
    end

    it "can specify the output file from command line" do
      pwd = File.expand_path(".")
      output_filename = "file_for_saving_result.txt"
      command_line_interface = AdHocTemplate::CommandLineInterface.new
      set_argv("-o #{output_filename}")
      command_line_interface.parse_command_line_options
      expect(command_line_interface.output_filename).to eq(File.join(pwd, output_filename))
    end

    it "can specify tag type for template" do
      command_line_interface = AdHocTemplate::CommandLineInterface.new
      set_argv("--tag-type=curly_brackets")
      command_line_interface.parse_command_line_options
      expect(command_line_interface.tag_type).to eq(:curly_brackets)
    end

    it "choose the default tag type when the given type is unkown" do
      command_line_interface = AdHocTemplate::CommandLineInterface.new
      set_argv("--tag-type=unkown_tag_type")
      command_line_interface.parse_command_line_options
      expect(command_line_interface.tag_type).to eq(:default)
    end

    it "can specify data format" do
      command_line_interface = AdHocTemplate::CommandLineInterface.new
      set_argv("--data-format=yaml")
      command_line_interface.parse_command_line_options
      expect(command_line_interface.data_format).to eq(:yaml)
    end

    it "choose the default data format when the given format is unkown" do
      command_line_interface = AdHocTemplate::CommandLineInterface.new
      set_argv("--data-format=unknown")
      command_line_interface.parse_command_line_options
      expect(command_line_interface.data_format).to eq(:default)
    end

    it "reads input data from command line" do
      template_filename = "template.txt"
      record_filename = "record.txt"
      template = "a dummy content of template file"
      record = "a dummy content of record file"

      allow(File).to receive(:read).with(File.expand_path(template_filename)).and_return(template)
      allow(File).to receive(:read).with(File.expand_path(record_filename)).and_return(record)

      set_argv("#{template_filename} #{record_filename}")
      command_line_interface = AdHocTemplate::CommandLineInterface.new
      command_line_interface.read_input_files

      expect(command_line_interface.template_data).to eq(template)
      expect(command_line_interface.record_data).to eq(record)
    end

    it "returns the result to the standard output unless an output file is specified." do
      template_filename = "template.txt"
      record_filename = "record.txt"

      allow(File).to receive(:read).with(File.expand_path(template_filename)).and_return(@template_in_default_format)
      allow(File).to receive(:read).with(File.expand_path(record_filename)).and_return(@record_in_default_format)
      allow(STDOUT).to receive(:print).with(@expected_result)

      set_argv("#{template_filename} #{record_filename}")
      command_line_interface = AdHocTemplate::CommandLineInterface.new
      command_line_interface.execute
    end

    it "can change the tag type." do
      template_filename = "template.txt"
      record_filename = "record.txt"

      template = <<TEMPLATE
a test string with tags ({{= key1 }} and {{= key2 }}) in it

{{#iteration_block
the value of sub_key1 is {{= sub_key1 }}
the value of sub_key2 is {{= sub_key2 }}

#}}
{{= block }}
TEMPLATE

      allow(File).to receive(:read).with(File.expand_path(template_filename)).and_return(template)
      allow(File).to receive(:read).with(File.expand_path(record_filename)).and_return(@record_in_default_format)
      allow(STDOUT).to receive(:print).with(@expected_result)

      set_argv("--tag-type=curly_brackets #{template_filename} #{record_filename}")
      command_line_interface = AdHocTemplate::CommandLineInterface.new
      command_line_interface.execute
    end

    it "can change the data format" do
record_in_yaml_format = <<YAML
key1: value1
key2: value2
key3: value3
"#iteration_block":
- sub_key1: value1-1
  sub_key2: value1-2
- sub_key1: value2-1
  sub_key2: value2-2
block: |
  the first line of block
  the second line of block

  the second paragraph in block
YAML

      template_filename = "template.txt"
      record_filename = "record.txt"

      allow(File).to receive(:read).with(File.expand_path(template_filename)).and_return(@template_in_default_format)
      allow(File).to receive(:read).with(File.expand_path(record_filename)).and_return(record_in_yaml_format)
      allow(STDOUT).to receive(:print).with(@expected_result)

      set_argv("--data-format=yaml #{template_filename} #{record_filename}")
      command_line_interface = AdHocTemplate::CommandLineInterface.new
      command_line_interface.parse_command_line_options
      expect(command_line_interface.data_format).to eq(:yaml)
      command_line_interface.execute
    end

    describe "--data-format=csv" do
      before do
        @record_in_csv_format = <<CSV
key1,key2,key3
value1-1,value1-2,value1-3
value2-1,value2-2,value2-3
value3-1,value3-2,value3-3
CSV

        @expected_result = <<RESULT
the value of sub_key1 is value1-1
the value of sub_key2 is value1-2
the value of sub_key2 is value1-3

the value of sub_key1 is value2-1
the value of sub_key2 is value2-2
the value of sub_key2 is value2-3

the value of sub_key1 is value3-1
the value of sub_key2 is value3-2
the value of sub_key2 is value3-3

RESULT

        @template_without_iteration_block = <<TEMPLATE
<%#iteration_block
the value of sub_key1 is <%= key1 %>
the value of sub_key2 is <%= key2 %>
the value of sub_key2 is <%= key3 %>

#%>
TEMPLATE
      end

      it "allows to specify a label when you choose CSV as data format" do
        command_line_interface = AdHocTemplate::CommandLineInterface.new
        set_argv("--data-format=csv:sub_records")
        command_line_interface.parse_command_line_options
        expect(command_line_interface.data_format).to eq({ csv: "sub_records" })
      end

      it "allows to specify as data format CSV as other formats" do
        command_line_interface = AdHocTemplate::CommandLineInterface.new
        set_argv("--data-format=csv")
        command_line_interface.parse_command_line_options
        expect(command_line_interface.data_format).to eq(:csv)
      end

      it "can read csv data with an iteration label" do
        template = <<TEMPLATE
<%#iteration_block
the value of sub_key1 is <%= key1 %>
the value of sub_key2 is <%= key2 %>
the value of sub_key2 is <%= key3 %>

#%>
TEMPLATE

        template_filename = "template.txt"
        record_filename = "record.csv"

        allow(File).to receive(:read).with(File.expand_path(template_filename)).and_return(template)
        allow(File).to receive(:read).with(File.expand_path(record_filename)).and_return(@record_in_csv_format)
        allow(STDOUT).to receive(:print).with(@expected_result)

        set_argv("--data-format=csv:iteration_block #{template_filename} #{record_filename}")
        command_line_interface = AdHocTemplate::CommandLineInterface.new
        command_line_interface.parse_command_line_options
        expect(command_line_interface.data_format).to eq({ csv: "iteration_block" })
        command_line_interface.execute
      end

      it "can read csv data without an iteration label" do
        template_filename = "template.txt"
        record_filename = "record.csv"

        allow(File).to receive(:read).with(File.expand_path(template_filename)).and_return(@template_without_iteration_block)
        allow(File).to receive(:read).with(File.expand_path(record_filename)).and_return(@record_in_csv_format)
        allow(STDOUT).to receive(:print).with(@expected_result)

        set_argv("--data-format=csv #{template_filename} #{record_filename}")
        command_line_interface = AdHocTemplate::CommandLineInterface.new
        command_line_interface.parse_command_line_options
        expect(command_line_interface.data_format).to eq(:csv)
        command_line_interface.execute
      end

      it "can read csv data of only one record" do
        record_in_csv_format = <<CSV
key1,key2,key3
value1-1,value1-2,value1-3
CSV

        expected_result = <<RESULT
the value of sub_key1 is value1-1
the value of sub_key2 is value1-2
the value of sub_key2 is value1-3

RESULT

        template_filename = "template.txt"
        record_filename = "record.csv"

        allow(File).to receive(:read).with(File.expand_path(template_filename)).and_return(@template_without_iteration_block)
        allow(File).to receive(:read).with(File.expand_path(record_filename)).and_return(record_in_csv_format)
        allow(STDOUT).to receive(:print).with(expected_result)

        set_argv("--data-format=csv #{template_filename} #{record_filename}")
        command_line_interface = AdHocTemplate::CommandLineInterface.new
        command_line_interface.parse_command_line_options
        expect(command_line_interface.data_format).to eq(:csv)
        command_line_interface.execute
      end
    end

    describe "--data-format=tsv" do
      before do
        @record_in_tsv_format = <<TSV
key1	key2	key3
value1-1	value1-2	value1-3
value2-1	value2-2	value2-3
value3-1	value3-2	value3-3
TSV

        @expected_result = <<RESULT
the value of sub_key1 is value1-1
the value of sub_key2 is value1-2
the value of sub_key2 is value1-3

the value of sub_key1 is value2-1
the value of sub_key2 is value2-2
the value of sub_key2 is value2-3

the value of sub_key1 is value3-1
the value of sub_key2 is value3-2
the value of sub_key2 is value3-3

RESULT

        @template_without_iteration_block = <<TEMPLATE
<%#iteration_block
the value of sub_key1 is <%= key1 %>
the value of sub_key2 is <%= key2 %>
the value of sub_key2 is <%= key3 %>

#%>
TEMPLATE
      end

      it "allows to specify a label when you choose TSV as data format" do
        command_line_interface = AdHocTemplate::CommandLineInterface.new
        set_argv("--data-format=tsv:sub_records")
        command_line_interface.parse_command_line_options
        expect(command_line_interface.data_format).to eq({ tsv: "sub_records" })
      end

      it "allows to specify as data format TSV as other formats" do
        command_line_interface = AdHocTemplate::CommandLineInterface.new
        set_argv("--data-format=tsv")
        command_line_interface.parse_command_line_options
        expect(command_line_interface.data_format).to eq(:tsv)
      end

      it "can read tsv data with an iteration label" do
        template = <<TEMPLATE
<%#iteration_block
the value of sub_key1 is <%= key1 %>
the value of sub_key2 is <%= key2 %>
the value of sub_key2 is <%= key3 %>

#%>
TEMPLATE

        template_filename = "template.txt"
        record_filename = "record.tsv"

        allow(File).to receive(:read).with(File.expand_path(template_filename)).and_return(template)
        allow(File).to receive(:read).with(File.expand_path(record_filename)).and_return(@record_in_tsv_format)
        allow(STDOUT).to receive(:print).with(@expected_result)

        set_argv("--data-format=tsv:iteration_block #{template_filename} #{record_filename}")
        command_line_interface = AdHocTemplate::CommandLineInterface.new
        command_line_interface.parse_command_line_options
        expect(command_line_interface.data_format).to eq({ tsv: "iteration_block" })
        command_line_interface.execute
      end

      it "can read tsv data without an iteration label" do
        template_filename = "template.txt"
        record_filename = "record.tsv"

        allow(File).to receive(:read).with(File.expand_path(template_filename)).and_return(@template_without_iteration_block)
        allow(File).to receive(:read).with(File.expand_path(record_filename)).and_return(@record_in_tsv_format)
        allow(STDOUT).to receive(:print).with(@expected_result)

        set_argv("--data-format=tsv #{template_filename} #{record_filename}")
        command_line_interface = AdHocTemplate::CommandLineInterface.new
        command_line_interface.parse_command_line_options
        expect(command_line_interface.data_format).to eq(:tsv)
        command_line_interface.execute
      end

      it "can read tsv data of only one record" do
        record_in_tsv_format = <<TSV
key1	key2	key3
value1-1	value1-2	value1-3
TSV

        expected_result = <<RESULT
the value of sub_key1 is value1-1
the value of sub_key2 is value1-2
the value of sub_key2 is value1-3

RESULT

        template_filename = "template.txt"
        record_filename = "record.tsv"

        allow(File).to receive(:read).with(File.expand_path(template_filename)).and_return(@template_without_iteration_block)
        allow(File).to receive(:read).with(File.expand_path(record_filename)).and_return(record_in_tsv_format)
        allow(STDOUT).to receive(:print).with(expected_result)

        set_argv("--data-format=tsv #{template_filename} #{record_filename}")
        command_line_interface = AdHocTemplate::CommandLineInterface.new
        command_line_interface.parse_command_line_options
        expect(command_line_interface.data_format).to eq(:tsv)
        command_line_interface.execute
      end
    end

    describe "by file extentions" do
      it "can guess the format of data" do
        template_filename = "template.txt"
        record_filename = "record.yaml"

        set_argv("#{template_filename} #{record_filename}")
        command_line_interface = AdHocTemplate::CommandLineInterface.new
        command_line_interface.parse_command_line_options
        expect(command_line_interface.data_format).to eq(:yaml)
      end
    end
  end
end
