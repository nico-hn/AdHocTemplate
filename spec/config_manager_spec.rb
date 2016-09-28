#!/usr/bin/env ruby

require 'shellwords'
require 'stringio'
require 'spec_helper'
require 'ad_hoc_template'
require 'ad_hoc_template/config_manager'

describe AdHocTemplate do
  describe AdHocTemplate::ConfigManager do
    describe '.require_local_settings' do
      let(:fake_file) { double('file') }

      before do
        @config_file = AdHocTemplate::ConfigManager::LOCAL_SETTINGS_FILE
        @config_full_path = File.expand_path(@config_file)
      end

      it 'loads local settings when the config file exists' do
        stub_const("File", fake_file)
        allow(File).to receive(:expand_path).with(@config_file).and_return(@config_full_path)
        allow(File).to receive(:exist?).with(@config_full_path).and_return(true)
        allow(AdHocTemplate::ConfigManager).to receive(:require).with(@config_full_path)
        AdHocTemplate::ConfigManager.require_local_settings
      end

      it 'does not do nothing if the config file is not available' do
        stub_const("File", fake_file)
        allow(File).to receive(:expand_path).with(@config_file).and_return(@config_full_path)
        allow(File).to receive(:exist?).with(@config_full_path).and_return(false)
        allow(AdHocTemplate::ConfigManager).to receive(:require).with(@config_full_path)
        AdHocTemplate::ConfigManager.require_local_settings
        expect(AdHocTemplate::ConfigManager).to_not have_received(:require).with(@config_full_path)
      end
    end
  end
end
