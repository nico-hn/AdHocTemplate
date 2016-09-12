#!/usr/bin/env ruby

require 'ad_hoc_template'
require 'optparse_plus'

module AdHocTemplate
  class CommandLineInterface
    attr_accessor :output_filename, :template_data, :record_data, :tag_type, :data_format
    attr_writer :output_empty_entry

    TAG_RE_TO_TYPE = {
      /\Ad(efault)?/i => :default,
      /\Ac(urly_brackets)?/i => :curly_brackets,
      /\As(quare_brackets)?/i => :square_brackets,
      /\Axml_like1/i => :xml_like1,
      /\Axml_like2/i => :xml_like2,
      /\Axml_comment_like/i => :xml_comment_like,
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

    def parse_command_line_options
      OptionParser.new_with_yaml do |opt|
        opt.banner = "USAGE: #{File.basename($0)} [OPTION]... TEMPLATE_FILE DATA_FILE"
        opt.version = AdHocTemplate::VERSION

        opt.inherit_ruby_options('E') # -E, --encoding
        opt.on(:output_file) {|output_file| @output_filename = File.expand_path(output_file) }
        opt.on(:tag_type) {|given_type| choose_tag_type(given_type) }
        opt.on(:data_format) {|data_format| choose_data_format(data_format) }
        opt.on(:tag_config) {|tag_config_yaml| register_user_defined_tag_type(tag_config_yaml) }
        opt.on(:entry_format) {|entry_format| @output_empty_entry = true }

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

    def render
      AdHocTemplate.render(@record_data, @template_data, @tag_type,
                            @data_format, @tag_formatter)
    end

    def generate_entry_format
      tree = Parser.parse(@template_data, @tag_type)
      EntryFormatGenerator.extract_labels(tree, @data_format)
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
      output = @output_empty_entry ? generate_entry_format : render
      open_output {|out| out.print output }
    end

    private

    def choose_tag_type(given_type)
      if_any_regex_match(TAG_RE_TO_TYPE, given_type,
                         "The given type is not found. The default tag is chosen.") do |re, tag_type|
        @tag_type = tag_type
      end
    end

    def choose_data_format(data_format)
      format_part, label_part = data_format.split(/:/, 2)
      if_any_regex_match(FORMAT_RE_TO_FORMAT, format_part,
                         "The given format is not found. The default format is chosen.") do |re, format|
        @data_format = [:csv, :tsv].include?(format) ? make_csv_option(label_part, format) : format
      end
    end

    def register_user_defined_tag_type(tag_config_yaml)
      config = File.read(File.expand_path(tag_config_yaml))
      @tag_type = Parser.register_user_defined_tag_type(config)
    end

    def make_csv_option(iteration_label, format)
      return format if iteration_label.nil? or iteration_label.empty?
      { format => iteration_label }
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

__END__
output_file:
  short: "-o [output_file]"
  long: "--output [=output_file]"
  description: "Save the result into the specified file."
tag_type:
  short: "-t [tag_type]"
  long: "--tag-type [=tag_type]"
  description: "Choose a template tag type: default, curly_brackets or square_brackets"
data_format:
  short: "-d [data_format]"
  long: "--data-format [=data_format]"
  description: "Specify the format of input data: default, yaml, json, csv or tsv"
tag_config:
  short: "-u [tag_config.yaml]"
  long: "--user-defined-tag [=tag_config.yaml]"
  description: "Configure a user-defined tag. The configuration file is in YAML format."
entry_format:
  short: "-e"
  long: "--entry-format"
  description: "Extract tag labels from a template and generate an empty data entry format"
