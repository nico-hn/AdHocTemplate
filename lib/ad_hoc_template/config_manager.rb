#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'

module AdHocTemplate
  class ConfigManager
    LOCAL_SETTINGS_DIR = '~/.ad_hoc_template/'
    SETTINGS_FILE_NAME = 'settings.rb'
    TAG_DEF_FILE_NAME = 'user_defined_tag.yaml'
    LOCAL_SETTINGS_FILE = File.join(LOCAL_SETTINGS_DIR,
                                    SETTINGS_FILE_NAME)

    def self.require_local_settings
      settings_file = File.expand_path(LOCAL_SETTINGS_FILE)
      require settings_file if File.exist? settings_file
    end

    def self.configure(&config_block)
      module_eval(&config_block)
    end

    def self.user_defined_tag(def_yaml_path)
      yaml_source = File.read(expand_path(def_yaml_path))
      AdHocTemplate::Parser.register_user_defined_tag_type(yaml_source)
    end

    def self.assign_format_label(format_label, &func)
      AdHocTemplate::DefaultTagFormatter.assign_format(format_label, &func)
    end

    def self.define_label_format(&block)
      AdHocTemplate::DefaultTagFormatter.module_eval(&block)
    end

    def self.init_local_settings
      config_dir = File.expand_path(LOCAL_SETTINGS_DIR)
      settings_rb = File.expand_path(LOCAL_SETTINGS_FILE)
      custom_tag_yaml = File.join(config_dir, TAG_DEF_FILE_NAME)
      FileUtils.mkdir(config_dir) unless File.exist? config_dir
      create_unless_exist(settings_rb, @local_settings_template)
      create_unless_exist(custom_tag_yaml, @custom_tag_template)
    end

    def self.expand_path(path)
      path = File.join(LOCAL_SETTINGS_DIR, path) unless %r{\A[\./]} =~ path
      File.expand_path(path)
    end

    def self.create_unless_exist(path, content)
      return if File.exist? path
      open(path, 'wb') {|file| file.print content }
    end

    private_class_method :create_unless_exist

    @local_settings_template = <<SETTING_TEMPLATE
AdHocTemplate.local_settings do
  ##
  # If you want to define your own tags for templates,
  # prepare a definition file in YAML format:
  #
  # An example of definition in YAML -----
  #    ---
  #    tag_name: :default
  #    tag: ["<%", "%>"]
  #    iteration_tag: ["<%#", "#%>"]
  #    fallback_tag: ["<%*", "*%>"]
  #    remove_indent: false
  #
  # And read the file by "user_defined_tag NAME_OF_YAML_FILE":
  #
  user_defined_tag 'user_defined_tag.yaml'

  ##
  # If you want to define a custom label format,
  # there are two ways to realize that.
  # Suppose you have data in YAML and want to
  # present the value of date field in French style:
  #
  # YAML data -----
  #    ---
  #    date: 2016/09/28
  #    other_field: ...
  #    ...
  #
  #  Template -----
  #
  #    Today = <%= date %>
  #    Aujourd'hui = <%fd date %>
  #
  #  Expected result -----
  #
  #    Today = 2016/09/28
  #    Aujourd'hui = 28/09/2016
  #
  # # The first way -----
  #
  # define_label_format do
  #   def french_date(var, record)
  #     record[var].split(/\\//).reverse.join('/')
  #   end
  #
  #   assign_format french_date: 'fd'
  # end
  #
  # # The second way -----
  #
  # assign_format_label('fd') do |var, record|
  #   record[var].split(/\\//).reverse.join('/')
  # end
  #
end
SETTING_TEMPLATE

    @custom_tag_template = <<TAG_TEMPLATE
---
tag_name: :default
tag: ["<%", "%>"]
iteration_tag: ["<%#", "#%>"]
fallback_tag: ["<%*", "*%>"]
remove_indent: false
TAG_TEMPLATE
  end
end
