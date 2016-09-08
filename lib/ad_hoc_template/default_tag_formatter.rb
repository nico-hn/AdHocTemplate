#!/usr/bin/env ruby

module AdHocTemplate
  class DefaultTagFormatter
    def find_function(tag_type)
      FUNCTION_TABLE[tag_type]||:default
    end

    def format(tag_type, var, record)
      self.send(find_function(tag_type), var, record)
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
