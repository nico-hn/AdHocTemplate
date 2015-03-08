#!/usr/bin/env ruby

require 'ad_hoc_template'
require 'optparse'

module AdHocTemplate
  class CommandLineInterface
    def set_encoding(given_opt)
      external, internal = given_opt.split(/:/o, 2)
      Encoding.default_external = external if external and not external.empty?
      Encoding.default_internal = internal if internal and not internal.empty?
    end
  end
end
