# frozen_string_literal: true

module AdHocTemplate
  ##
  # Provide methods that are not availabe in older versions of Ruby.

  module Shim
    refine Regexp do
      ##
      # Regexp.match?() is available for Ruby >= 2.4,
      # and the following implementation does not satisfy
      # the full specification of the original method.

      alias_method(:match?, :===)
    end
  end
end
