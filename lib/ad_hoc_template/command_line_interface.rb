# frozen_string_literal: true

require 'ad_hoc_template'
require 'optparse_plus'
require 'ad_hoc_template/config_manager'
require 'ad_hoc_template/recipe_manager'
require 'ad_hoc_template/utils'

AdHocTemplate::ConfigManager.require_local_settings

module AdHocTemplate
  class CommandLineInterface
    include Utils
    attr_accessor :output_filename, :tag_type, :data_format,
                  :template_data, :record_data
    attr_writer :output_empty_entry

    TAG_RE_TO_TYPE = {
      /\Ad(efault)?/i => :default,
      /\Ac(urly_brackets)?/i => :curly_brackets,
      /\As(quare_brackets)?/i => :square_brackets,
      /\Axml_like1/i => :xml_like1,
      /\Axml_like2/i => :xml_like2,
      /\Axml_comment_like/i => :xml_comment_like,
    }.freeze

    RE_TO_FORMAT = {
      /\Ad(efault)?/i => :default,
      /\Ay(a?ml)?/i => :yaml,
      /\Aj(son)?/i => :json,
      /\Ac(sv)?/i => :csv,
      /\At(sv)?/i => :tsv,
    }.freeze

    def initialize
      @tag_formatter = AdHocTemplate::DefaultTagFormatter.new
      @output_filename = nil
      @tag_type = :default
      @data_format = nil
      @force_update = false
      @init_local_settings = false
    end

    def parse_command_line_options
      OptionParser.new_with_yaml do |opt|
        opt.banner = "USAGE: #{File.basename($0)} [OPTION]... TEMPLATE_FILE DATA_FILE"
        opt.version = AdHocTemplate::VERSION

        opt.inherit_ruby_options('E') # -E, --encoding
        opt.on(:output_file) {|file| @output_filename = File.expand_path(file) }
        opt.on(:tag_type) {|given_type| choose_tag_type(given_type) }
        opt.on(:data_format) {|data_format| choose_data_format(data_format) }
        opt.on(:tag_config) {|yaml| register_user_defined_tag_type(yaml) }
        opt.on(:entry_format) { @output_empty_entry = true }
        opt.on(:init_local_settings) { init_local_settings }
        opt.on(:recipe_template) { @output_recipe_template = true }
        opt.on(:cooking_recipe) {|recipe_yaml| @recipe_yaml = recipe_yaml }
        opt.on(:force_update) { @force_update = true }

        opt.parse!
      end

      unless @data_format
        guessed_format = ARGV.length < 2 ? :default : guess_file_format(ARGV[1])
        @data_format = guessed_format || :default
      end
    end

    def read_input_files
      template, record = ARGV.map {|arg| File.expand_path(arg) if arg }
      if template
        @template_data = File.read(template)
      else
        STDERR.puts 'No template file is given.'
      end

      @record_data = record ? File.read(record) : ARGF.read
    end

    def render
      AdHocTemplate.render(@record_data, @template_data, @tag_type,
                           @data_format, @tag_formatter)
    end

    def generate_entry_format
      tree = Parser.parse(@template_data, @tag_type)
      EntryFormatGenerator.extract_form(tree, @data_format)
    end

    def init_local_settings
      AdHocTemplate::ConfigManager.init_local_settings
      config_dir = ConfigManager.expand_path('')
      puts "Please edit configuration files created in #{config_dir}"
      @init_local_settings = true
    end

    def generate_recipe_template(templates)
      encoding = Encoding.default_external.names[0]
      AdHocTemplate::EntryFormatGenerator
        .extract_recipes_from_template_files(templates, @tag_type, encoding)
    end

    def update_output_files_in_recipe(recipe)
      AdHocTemplate::RecipeManager
        .update_output_files_in_recipe(recipe, @force_update)
    end

    def open_output
      if @output_filename
        File.open(@output_filename, 'wb') {|out| yield out }
      else
        yield STDOUT
      end
    end

    def execute
      parse_command_line_options
      exit if @init_local_settings
      return update_output_files_in_recipe(@recipe_yaml) if @recipe_yaml
      read_input_files
      open_output {|out| out.print generate_output }
    end

    private

    def generate_output
      return generate_entry_format if @output_empty_entry
      return generate_recipe_template(ARGV) if @output_recipe_template
      render
    end

    def choose_tag_type(given_type)
      err_msg = 'The given type is not found. The default tag is chosen.'

      if_any_regex_match(TAG_RE_TO_TYPE, given_type, err_msg) do |_, tag_type|
        @tag_type = tag_type
      end
    end

    def choose_data_format(data_format)
      err_msg = 'The given format is not found. The default format is chosen.'
      format_part, label_part = data_format.split(/:/, 2)

      if_any_regex_match(RE_TO_FORMAT, format_part, err_msg) do |_, format|
        csv_with_label = value_assigned?(label_part) && csv_or_tsv?(format)
        @data_format = csv_with_label ? { format => label_part } : format
      end
    end

    def register_user_defined_tag_type(tag_config_yaml)
      config = File.read(File.expand_path(tag_config_yaml))
      @tag_type = Parser.register_user_defined_tag_type(config)
    end

    def value_assigned?(iteration_label)
      !(iteration_label.nil? || iteration_label.empty?)
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
init_local_settings:
  long: "--init-local-settings"
  description: "Generate configuration files for local settings"
recipe_template:
  short: "-R"
  long: "--recipe-template"
  description: "Generate recipe entries for template files given on the command line"
cooking_recipe:
  short: "-c [recipe_yaml]"
  long: "--cooking-recipe [=recipe_yaml]"
  description: "Update output files specified in the recipe file"
force_update:
  long: "--force-update"
  description: "Update output files in recipe, even when they are newer than template/data files"
