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
      before do
        @function_table = AdHocTemplate::DefaultTagFormatter:: FUNCTION_TABLE
        @var = 'french_date'
        @record = { @var => '2016/09/28' }
        @expected_result = '28/09/2016'
      end

      it '.assign_format_label is an alias of DefaultTagFormatter.assign_format' do
        AdHocTemplate.local_settings do
          assign_format_label('fd') {|var, record| record[var].split(/\//).reverse.join('/') }
        end

        result = @function_table['fd'].call(@var, @record)

        expect(result).to eq(@expected_result)

        @function_table.delete('fd')
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

        method_name = @function_table['fd']
        result = AdHocTemplate::DefaultTagFormatter.new.send method_name, @var, @record

        expect(result).to eq(@expected_result)

        AdHocTemplate::DefaultTagFormatter.send :undef_method, method_name
      end
    end

    describe '.init_local_settings' do
      before do
        @config_manager = AdHocTemplate::ConfigManager
        @settings_dir = File.expand_path(@config_manager::LOCAL_SETTINGS_DIR)
        @setting_file_name = @config_manager::SETTINGS_FILE_NAME
        @tag_def_file_name = @config_manager::TAG_DEF_FILE_NAME
        @settings_path = File.expand_path(File.join(@settings_dir, @setting_file_name))
        @settings_file = StringIO.new('', "w")
        @tag_def_path = File.expand_path(File.join(@settings_dir, @tag_def_file_name))
        @tag_def_file = StringIO.new('', "w")
      end

      it 'creates local setting files unless they exist' do
        allow(File).to receive(:exist?).with(@settings_dir).and_return(false)
        allow(FileUtils).to receive(:mkdir).and_return(true)
        allow(File).to receive(:exist?).with(@settings_path).and_return(false)
        allow(@config_manager).to receive(:open).with(@settings_path, 'w').and_yield(@settings_file)
        allow(File).to receive(:exist?).with(@tag_def_path).and_return(false)
        allow(@config_manager).to receive(:open).with(@tag_def_path, 'w').and_yield(@tag_def_file)

        @config_manager.init_local_settings

        expect(@settings_file.string).to start_with('AdHocTemplate')
        expect(@tag_def_file.string).to start_with('---')
      end
    end
  end
end
