# frozen_string_literal: true

require_relative "udon/version"

begin
  # Load the native extension
  require "udon/udon"
rescue LoadError => e
  warn "Failed to load native UDON extension: #{e.message}"
  warn "Try running: bundle exec rake compile"
  raise
end

# UDON (Universal Document & Object Notation) parser
#
# High-performance parser with native Rust extension.
#
# @example Parse a UDON document
#   events = Udon.parse("|div Hello, world!")
#   events.each do |event|
#     case event[:type]
#     when :element_start
#       puts "Element started"
#     when :name
#       puts "Name: #{event[:content]}"
#     when :text
#       puts "Text: #{event[:content]}"
#     end
#   end
#
module Udon
  class Error < StandardError; end
  class ParseError < Error; end

  class << self
    # Parse a UDON document and return an array of events.
    #
    # @param input [String] The UDON document to parse
    # @return [Array<Hash>] Array of event hashes
    # @raise [ParseError] If parsing fails catastrophically
    #
    # Event types (all have :span with :start/:end):
    #
    # Bracket events (start/end pairs):
    # - :element_start, :element_end
    # - :embedded_start, :embedded_end
    # - :directive_start, :directive_end
    # - :array_start, :array_end
    # - :freeform_start, :freeform_end
    # - :comment_start, :comment_end
    #
    # Content events (have :content):
    # - :name - element/directive name
    # - :text - text content
    # - :attr - attribute name
    # - :string_value - quoted string value
    # - :bare_value - unquoted value
    # - :bool_true, :bool_false - boolean values
    # - :nil - nil/null value
    # - :integer, :float, :rational, :complex - numeric values
    # - :interpolation - interpolation expression
    # - :reference - reference content
    # - :raw_content, :raw - raw content
    # - :warning - parser warning
    #
    # Error events:
    # - :error - has :code instead of :content
    #
    def parse(input)
      input = input.to_s
      input = input.encode(Encoding::UTF_8) unless input.encoding == Encoding::UTF_8
      UdonNative.parse(input)
    end
  end
end
