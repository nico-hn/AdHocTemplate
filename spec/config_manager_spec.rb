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

    describe '.user_defined_tag' do
      it 'reads a definition from local file and register it' do
        tag_type_class = AdHocTemplate::Parser::TagType

        yaml_file_name = 'def_tag.yaml'
        yaml_file_path = File.expand_path(yaml_file_name)
        yaml_source = <<YAML
---
tag_name: :test_tag
tag: ['<$', '$>']
iteration_tag: ['<$#', '#$>']
fallback_tag: ['<$*', '*$>']
remove_indent: false
YAML

        allow(File).to receive(:read).with(yaml_file_path).and_return(yaml_source)
        allow(File).to receive(:expand_path).and_return(yaml_file_path)

        AdHocTemplate::ConfigManager.user_defined_tag(yaml_file_name)

        expect(tag_type_class[:test_tag]).to be_instance_of(tag_type_class)
      end
    end

    describe 'DefaultTagFormatter related methods' do
      it '.assign_format_label is an alias of DefaultTagFormatter.assign_format' do
        AdHocTemplate.local_settings do
          assign_format_label('fd') {|var, record| record[var].split(/\//).reverse.join('/') }
        end

        var = 'french_date'
        record = { var => '2016/09/28' }
        result = AdHocTemplate::DefaultTagFormatter:: FUNCTION_TABLE['fd'].call(var, record)

        expect(result).to eq('28/09/2016')

        AdHocTemplate::DefaultTagFormatter:: FUNCTION_TABLE.delete('fd')
      end

      it '.define_label_format evaluates a given block in the context of DefaultTagFormatter' do
        AdHocTemplate.local_settings do
          define_label_format do
            def french_date(var, record)
              record[var].split(/\//).reverse.join('/')
            end

            assign_format french_date: 'fd'
          end
        end

        var = 'french_date'
        record = { var => '2016/09/28' }
        method_name = AdHocTemplate::DefaultTagFormatter:: FUNCTION_TABLE['fd']
        result = AdHocTemplate::DefaultTagFormatter.new.send method_name, var, record

        expect(result).to eq('28/09/2016')

        AdHocTemplate::DefaultTagFormatter.send :undef_method, method_name
      end
    end
  end
end
