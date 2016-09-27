#!/usr/bin/env ruby

require 'fileutils'

module AdHocTemplate
  class ConfigManager
    LOCAL_SETTINGS_FILE = '~/.ad_hoc_template/settings.rb'

    def self.require_local_settings
      settings_file = File.expand_path(LOCAL_SETTINGS_FILE)
      if File.exist? settings_file
        require settings_file
      end
    end
  end
end
