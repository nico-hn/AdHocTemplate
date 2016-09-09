#!/usr/bin/env ruby

require 'pseudohikiparser'

module AdHocTemplate
  class DefaultTagFormatter
    module PseudoHikiFormatter
      include PseudoHiki

      def self.to_xhtml(var, record)
        hiki_source = record[var] || var
        parser = choose_parser(hiki_source)
        PseudoHiki::XhtmlFormat.format(parser.parse(hiki_source)).to_s
      end

      def self.choose_parser(hiki_source)
        hiki_source[/(?:\r?\n|\r)/] ? BlockParser : InlineParser
      end

      private_class_method :choose_parser
    end

    assign_format("ph") {|var, record| PseudoHikiFormatter.to_xhtml(var, record) }
  end
end