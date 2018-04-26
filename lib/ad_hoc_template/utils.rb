# frozen_string_literal: true

module AdHocTemplate
  module Utils
    FILE_EXTENTIONS = {
      /\.ya?ml\Z/i => :yaml,
      /\.json\Z/i => :json,
      /\.csv\Z/i => :csv,
      /\.tsv\Z/i => :tsv,
    }.freeze

    def guess_file_format(filename)
      if_any_regex_match(FILE_EXTENTIONS, filename) do |_, format|
        return format
      end
    end

    def if_any_regex_match(regex_table, target, failure_message=nil)
      regex_table.each do |re, paired_value|
        if re =~ target
          yield re, paired_value
          return nil
        end
      end
      STDERR.puts failure_message if failure_message
      nil
    end

    private

    def csv_or_tsv?(format)
      %i[csv tsv].include? format
    end
  end
end
