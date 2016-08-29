#!/usr/bin/env ruby

require 'ad_hoc_template'
require 'optparse'

module AdHocTemplate
  class CommandLineInterface
    attr_accessor :output_filename, :template_data, :record_data, :tag_type, :data_format

    TAG_RE_TO_TYPE = {
      /\Ad(efault)?/i => :default,
      /\Ac(urly_brackets)?/i => :curly_brackets,
      /\As(quare_brackets)?/i => :square_brackets,
    }

    FORMAT_RE_TO_FORMAT = {
      /\Ad(efault)?/i => :default,
      /\Ay(a?ml)?/i => :yaml,
      /\Aj(son)?/i => :json,
      /\Ac(sv)?/i => :csv,
      /\At(sv)?/i => :tsv,
    }

    FILE_EXTENTIONS = {
      /\.ya?ml\Z/i => :yaml,
      /\.json\Z/i => :json,
      /\.csv\Z/i => :csv,
      /\.tsv\Z/i => :tsv,
    }

    def initialize
      @tag_formatter = AdHocTemplate::DefaultTagFormatter.new
      @output_filename = nil
      @tag_type = :default
      @data_format = nil
    end

    def set_encoding(given_opt)
      external, internal = given_opt.split(/:/o, 2)
      Encoding.default_external = external if external and not external.empty?
      Encoding.default_internal = internal if internal and not internal.empty?
    end

    def parse_command_line_options
      OptionParser.new("USAGE: #{File.basename($0)} [OPTION]... TEMPLATE_FILE DATA_FILE") do |opt|
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

        opt.on("-d [data_format]", "--data-format [=data_format]",
               "Specify the format of input data: default, yaml, json, csv or tsv") do |data_format|
          choose_data_format(data_format)
        end

       opt.parse!
      end

      unless @data_format
        guessed_format = ARGV.length < 2 ? :default : guess_file_format(ARGV[1])
        @data_format =  guessed_format || :default
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
      AdHocTemplate.convert(@record_data, @template_data, @tag_type,
                            @data_format, @tag_formatter)
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
      if_any_regex_match(TAG_RE_TO_TYPE, given_type,
                         "The given type is not found. The default tag is chosen.") do |re, tag_type|
        @tag_type = tag_type
      end
    end

    def choose_data_format(data_format)
      if_any_regex_match(FORMAT_RE_TO_FORMAT, data_format,
                         "The given format is not found. The default format is chosen.") do |re, format|
        @data_format = [:csv, :tsv].include?(format) ? make_csv_option(data_format, format) : format
      end
    end

    def make_csv_option(data_format, format)
      iteration_label = data_format.sub(/\A(csv|tsv):?/, "")
      iteration_label.empty? ? format : { format => iteration_label }
    end

    def guess_file_format(filename)
      if_any_regex_match(FILE_EXTENTIONS, filename) do |ext_re, format|
        return format
      end
    end

    def if_any_regex_match(regex_table, target, failure_message=nil)
      regex_table.each do |re, paired_value|
        if re =~ target
          yield re, paired_value
          return
        end
      end
      STDERR.puts failure_message if failure_message
      nil
    end
  end
end
