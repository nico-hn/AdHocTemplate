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
  end
end
