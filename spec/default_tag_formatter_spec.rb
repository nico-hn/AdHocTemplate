#!/usr/bin/env ruby

require 'spec_helper'
require 'ad_hoc_template'

describe AdHocTemplate do
  describe AdHocTemplate::DefaultTagFormatter do
    before do
      @record = {
        'var1' => '<value1>',
        'var2' => 'value2'
      }
    end

    it 'has "=" format label for the default format' do
      formatter = AdHocTemplate::DefaultTagFormatter.new
      default = formatter.format('=', 'var1', @record)
      expect(default).to eq('<value1>')
    end

    it 'has "h" format label for HTML encoding' do
      formatter = AdHocTemplate::DefaultTagFormatter.new
      default = formatter.format('h', 'var1', @record)
      expect(default).to eq('&lt;value1&gt;')
    end

    it 'proc objects may be assigned in DefaultTagFormatter::FUNCTION_TABLE' do
      proc_label = 'proc_label'
      function_table = AdHocTemplate::DefaultTagFormatter::FUNCTION_TABLE
      function_table[proc_label] = proc {|var, record| "test for proc assignment: #{record[var]}" }
      formatter = AdHocTemplate::DefaultTagFormatter.new
      proc_assigned = formatter.format(proc_label, 'var1', @record)
      function_table.delete(proc_label)
      expect(proc_assigned).to eq('test for proc assignment: <value1>')
    end
  end
end

