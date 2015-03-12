#!/usr/bin/env ruby

require 'shellwords'
require 'spec_helper'
require 'ad_hoc_template'
require 'ad_hoc_template/command_line_interface'

describe AdHocTemplate do
  describe AdHocTemplate::CommandLineInterface do
    it "can set the input/output encoding" do
      command_line_interface = AdHocTemplate::CommandLineInterface.new
      command_line_interface.set_encoding("UTF-8:Shift_JIS")
      expect(command_line_interface.class::Encoding.default_external.names).to include("UTF-8")
      expect(command_line_interface.class::Encoding.default_internal.names).to include("Shift_JIS")
    end

    it "accepts an internal only argument" do
      command_line_interface = AdHocTemplate::CommandLineInterface.new
      command_line_interface.set_encoding(":UTF-8")
      expect(command_line_interface.class::Encoding.default_internal.names).to include("UTF-8")
    end

    it "accepts also an external only argument" do
      command_line_interface = AdHocTemplate::CommandLineInterface.new
      command_line_interface.set_encoding("Shift_JIS")
      expect(command_line_interface.class::Encoding.default_external.names).to include("Shift_JIS")
      command_line_interface.set_encoding("UTF-8:")
      expect(command_line_interface.class::Encoding.default_external.names).to include("UTF-8")
    end

    it "can set the internal/external encoding from the command line" do
      command_line_interface = AdHocTemplate::CommandLineInterface.new
      set_argv("-E UTF-8:Shift_JIS")
      command_line_interface.parse_command_line_options
      expect(command_line_interface.class::Encoding.default_external.names).to include("UTF-8")
      expect(command_line_interface.class::Encoding.default_internal.names).to include("Shift_JIS")
    end

    it "can specify the output file from command line" do
      pwd = File.expand_path(".")
      output_filename = "file_for_saving_result.txt"
      command_line_interface = AdHocTemplate::CommandLineInterface.new
      set_argv("-o #{output_filename}")
      command_line_interface.parse_command_line_options
      expect(command_line_interface.output_filename).to eq(File.join(pwd, output_filename))
    end
  end
end
