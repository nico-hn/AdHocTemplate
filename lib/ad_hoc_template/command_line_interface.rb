#!/usr/bin/env ruby

require 'ad_hoc_template'
require 'optparse'

module AdHocTemplate
  class CommandLineInterface
    attr_accessor :output_filename

    def initialize
      @output_filename = nil
    end

    def set_encoding(given_opt)
      external, internal = given_opt.split(/:/o, 2)
      Encoding.default_external = external if external and not external.empty?
      Encoding.default_internal = internal if internal and not internal.empty?
    end

    def parse_command_line_options
      OptionParser.new do |opt|
        opt.on("-E [ex[:in]]", "--encoding [=ex[:in]]",
               "Specify the default external and internal character encodings (same as the option of MRI") do |given_opt|
          self.set_encoding(given_opt)
        end

        opt.on("-o [output_file]", "--output [=output_file]",
               "Save the result into the specified file.") do |output_file|
          @output_filename = File.expand_path(output_file)
        end

       opt.parse!
      end
    end
  end
end
