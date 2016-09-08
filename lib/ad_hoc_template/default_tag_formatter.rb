#!/usr/bin/env ruby

module AdHocTemplate
  class DefaultTagFormatter
    FUNCTION_TABLE = {
      "=" => :default,
      "h" => :html_encode
    }

    def self.assign_format(format_label, &func)
      FUNCTION_TABLE[format_label] = func
    end

    def find_function(format_label)
      FUNCTION_TABLE[format_label]||:default
    end

    def format(format_label, var, record)
      func = find_function(format_label)
      case func
      when Symbol, String
        self.send(func, var, record)
      else
        func.call(var, record)
      end
    end

    def default(var, record)
      record[var]||"[#{var}]"
    end

    def html_encode(var, record)
      HtmlElement.escape(record[var]||var)
    end
  end
end
