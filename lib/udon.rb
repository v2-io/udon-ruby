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
#       puts "Element: #{event[:name]}"
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
    # Event types and their fields:
    # - :element_start - name, id, classes, suffix, span
    # - :element_end - span
    # - :attribute - key, value, span
    # - :text - content, span
    # - :comment - content, span
    # - :embedded_start - name, id, classes, span
    # - :embedded_end - span
    # - :directive_start - name, namespace, is_raw, span
    # - :directive_end - span
    # - :inline_directive - name, namespace, is_raw, content, span
    # - :interpolation - expression, span
    # - :raw_content - content, span
    # - :id_reference - id, span
    # - :attribute_merge - id, span
    # - :freeform_start - span
    # - :freeform_end - span
    # - :error - message, span
    #
    def parse(input)
      input = input.to_s
      input = input.encode(Encoding::UTF_8) unless input.encoding == Encoding::UTF_8
      UdonNative.parse(input)
    end
  end
end
