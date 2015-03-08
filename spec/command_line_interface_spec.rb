#!/usr/bin/env ruby

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
  end
end
