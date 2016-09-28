#!/usr/bin/env ruby

require 'fileutils'

module AdHocTemplate
  class ConfigManager
    LOCAL_SETTINGS_DIR = '~/.ad_hoc_template/'
    SETTINGS_FILE_NAME = 'settings.rb'
    LOCAL_SETTINGS_FILE = File.join(LOCAL_SETTINGS_DIR,
                                    SETTINGS_FILE_NAME)

    def self.require_local_settings
      settings_file = File.expand_path(LOCAL_SETTINGS_FILE)
      if File.exist? settings_file
        require settings_file
      end
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

    def self.expand_path(path)
      unless /\A[\.\/]/ =~ path
        path = File.join(LOCAL_SETTINGS_DIR, path)
      end
      File.expand_path(path)
    end

    private_class_method :expand_path
  end
end
