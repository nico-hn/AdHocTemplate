#!/usr/bin/env ruby

module AdHocTemplate
  class DefaultTagFormatter
    def find_function(format_label)
      FUNCTION_TABLE[format_label]||:default
    end

    def format(format_label, var, record)
      self.send(find_function(format_label), var, record)
    end

    def default(var, record)
      record[var]||"[#{var}]"
    end

    def html_encode(var, record)
      HtmlElement.escape(record[var]||var)
    end

    FUNCTION_TABLE = {
      "=" => :default,
      "h" => :html_encode
    }
  end
end
