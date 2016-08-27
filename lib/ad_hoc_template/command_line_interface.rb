#!/usr/bin/env ruby

require 'ad_hoc_template'
require 'optparse'

module AdHocTemplate
  class CommandLineInterface
    attr_accessor :output_filename, :template_data, :record_data, :tag_type

    TAG_RE_TO_TYPE = {
      /\Ad(efault)?/i => :default,
      /\Ac(urly_brackets)?/i => :curly_brackets,
      /\As(quare_brackets)?/i => :square_brackets,
    }

    def initialize
      @formatter = AdHocTemplate::DefaultTagFormatter.new
      @output_filename = nil
      @tag_type = :default
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

        opt.on("-t [tag_type]", "--tag-type [=tag_type]",
               "Choose a template tag type: default, curly_brackets or square_brackets") do |given_type|
          choose_tag_type(given_type)
        end

       opt.parse!
      end
    end

    def read_input_files
      template, record = ARGV.map {|arg| File.expand_path(arg) if arg }
      if template
        @template_data = File.read(template)
      else
        STDERR.puts "No template file is given."
      end

      @record_data = record ? File.read(record) : ARGF.read
    end

    def convert
      AdHocTemplate::Converter.convert(@record_data, @template_data, @formatter)
    end

    def open_output
      if @output_filename
        open(@output_filename, "wb") do |out|
          yield out
        end
      else
        yield STDOUT
      end
    end

    def execute
      parse_command_line_options
      read_input_files
      open_output do |out|
        out.print convert
      end
    end

    private

    def choose_tag_type(given_type)
      TAG_RE_TO_TYPE.each do |re, tag_type|
        if re =~ given_type
          @tag_type = tag_type
          return
        end
      end
      STDERR.puts "The given type is not found. The default tag is chosen."
    end
  end
end
