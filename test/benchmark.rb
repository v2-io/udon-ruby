#!/usr/bin/env ruby
# frozen_string_literal: true

# Performance comparison: UDON vs YAML vs XML
#
# Measures elements/second for semantic fairness across formats.
# All benchmarks include full traversal to defeat lazy evaluation.
#
# Run: bundle exec rake bench

require_relative '../lib/udon'
require 'yaml'
require 'rexml/document'
require 'benchmark'

begin
  require 'nokogiri'
  HAS_NOKOGIRI = true
rescue LoadError
  HAS_NOKOGIRI = false
  puts "Note: Install nokogiri gem for fast XML comparison"
end

# Generate test documents of various sizes
def generate_udon(depth, breadth, text_size)
  lines = []
  generate_udon_recursive(lines, "", depth, breadth, text_size)
  lines.join("\n") + "\n"
end

def generate_udon_recursive(lines, indent, depth, breadth, text_size)
  return if depth <= 0

  breadth.times do |i|
    text = "Content #{i} " * (text_size / 10)
    lines << "#{indent}|item[id-#{depth}-#{i}].class-a.class-b :attr value-#{i}"
    lines << "#{indent}  #{text}" unless text.empty?
    generate_udon_recursive(lines, indent + "  ", depth - 1, breadth, text_size)
  end
end

def generate_yaml(depth, breadth, text_size)
  generate_yaml_recursive(depth, breadth, text_size, 0)
end

def generate_yaml_recursive(depth, breadth, text_size, level)
  return "" if depth <= 0

  indent = "  " * level
  lines = []

  breadth.times do |i|
    text = "Content #{i} " * (text_size / 10)
    lines << "#{indent}- id: id-#{depth}-#{i}"
    lines << "#{indent}  class: [class-a, class-b]"
    lines << "#{indent}  attr: value-#{i}"
    lines << "#{indent}  text: \"#{text}\"" unless text.empty?
    children = generate_yaml_recursive(depth - 1, breadth, text_size, level + 1)
    lines << "#{indent}  children:" unless children.empty?
    lines << children unless children.empty?
  end

  lines.join("\n")
end

def generate_xml(depth, breadth, text_size)
  "<?xml version=\"1.0\"?>\n<root>\n" +
    generate_xml_recursive(depth, breadth, text_size, 1) +
    "</root>\n"
end

def generate_xml_recursive(depth, breadth, text_size, level)
  return "" if depth <= 0

  indent = "  " * level
  lines = []

  breadth.times do |i|
    text = "Content #{i} " * (text_size / 10)
    lines << "#{indent}<item id=\"id-#{depth}-#{i}\" class=\"class-a class-b\" attr=\"value-#{i}\">"
    lines << "#{indent}  #{text}" unless text.empty?
    lines << generate_xml_recursive(depth - 1, breadth, text_size, level + 1)
    lines << "#{indent}</item>"
  end

  lines.join("\n")
end

# ========== Traversal Functions ==========
# Returns [element_count, attr_count, text_bytes, library_calls]

def traverse_udon_events(events)
  elements = 0
  attrs = 0
  text_bytes = 0
  calls = events.size  # Each event is one "call" from the parser

  events.each do |event|
    case event[:type]
    when :element_start, :embedded_start
      elements += 1
    when :attr
      attrs += 1
    when :text, :raw_content, :raw
      content = event[:content]
      text_bytes += content.bytesize if content
    end
    # Force access to span (ensures we're reading all data)
    span = event[:span]
    _ = span[:start] if span
    _ = span[:end] if span
  end

  { elements: elements, attrs: attrs, text_bytes: text_bytes, calls: calls }
end

def traverse_yaml(data, depth = 0)
  elements = 0
  attrs = 0
  text_bytes = 0
  calls = 1  # This recursive call

  case data
  when Array
    data.each do |item|
      result = traverse_yaml(item, depth + 1)
      elements += result[:elements]
      attrs += result[:attrs]
      text_bytes += result[:text_bytes]
      calls += result[:calls]
    end
  when Hash
    elements += 1
    data.each do |key, value|
      attrs += 1
      text_bytes += key.to_s.bytesize
      result = traverse_yaml(value, depth + 1)
      elements += result[:elements]
      attrs += result[:attrs]
      text_bytes += result[:text_bytes]
      calls += result[:calls]
    end
  when String
    text_bytes += data.bytesize
  end

  { elements: elements, attrs: attrs, text_bytes: text_bytes, calls: calls }
end

def traverse_nokogiri(node)
  elements = 0
  attrs = 0
  text_bytes = 0
  calls = 1

  case node
  when Nokogiri::XML::Element
    elements += 1
    node.attributes.each do |name, attr|
      attrs += 1
      _ = name
      _ = attr.value
    end
    node.children.each do |child|
      result = traverse_nokogiri(child)
      elements += result[:elements]
      attrs += result[:attrs]
      text_bytes += result[:text_bytes]
      calls += result[:calls]
    end
  when Nokogiri::XML::Text
    text_bytes += node.content.bytesize
    calls += 1
  when Nokogiri::XML::Document
    node.children.each do |child|
      result = traverse_nokogiri(child)
      elements += result[:elements]
      attrs += result[:attrs]
      text_bytes += result[:text_bytes]
      calls += result[:calls]
    end
  end

  { elements: elements, attrs: attrs, text_bytes: text_bytes, calls: calls }
end

def traverse_rexml(node)
  elements = 0
  attrs = 0
  text_bytes = 0
  calls = 1

  case node
  when REXML::Element
    elements += 1
    node.attributes.each do |name, value|
      attrs += 1
      _ = name
      _ = value
    end
    node.children.each do |child|
      result = traverse_rexml(child)
      elements += result[:elements]
      attrs += result[:attrs]
      text_bytes += result[:text_bytes]
      calls += result[:calls]
    end
  when REXML::Text
    text_bytes += node.value.bytesize
    calls += 1
  when REXML::Document
    node.children.each do |child|
      result = traverse_rexml(child)
      elements += result[:elements]
      attrs += result[:attrs]
      text_bytes += result[:text_bytes]
      calls += result[:calls]
    end
  end

  { elements: elements, attrs: attrs, text_bytes: text_bytes, calls: calls }
end

def run_benchmark(name, iterations, &block)
  # Warmup
  3.times { block.call }
  GC.start

  times = []
  iterations.times do
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    block.call
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    times << elapsed
  end

  avg = times.sum / times.size
  min = times.min
  max = times.max

  { name: name, avg: avg, min: min, max: max }
end

def format_rate(count, seconds)
  rate = count / seconds
  if rate >= 1_000_000
    "#{(rate / 1_000_000).round(2)}M/s"
  elsif rate >= 1_000
    "#{(rate / 1_000).round(1)}K/s"
  else
    "#{rate.round(0)}/s"
  end
end

def format_time(seconds)
  if seconds < 0.001
    "#{(seconds * 1_000_000).round(1)} µs"
  elsif seconds < 1
    "#{(seconds * 1_000).round(2)} ms"
  else
    "#{seconds.round(3)} s"
  end
end

puts "=" * 78
puts "UDON Parser Performance Benchmark"
puts "=" * 78
puts
puts "All benchmarks include full AST traversal (defeats lazy evaluation)."
puts "Metrics: elements/second for semantic comparison across formats."
puts

configs = [
  { name: "Small",  depth: 2, breadth: 3,  text: 20,  iters: 100 },
  { name: "Medium", depth: 3, breadth: 5,  text: 50,  iters: 50 },
  { name: "Large",  depth: 4, breadth: 5,  text: 100, iters: 20 },
]

configs.each do |config|
  puts "-" * 78
  puts "#{config[:name]} document (depth=#{config[:depth]}, breadth=#{config[:breadth]})"
  puts "-" * 78

  udon_doc = generate_udon(config[:depth], config[:breadth], config[:text])
  yaml_doc = generate_yaml(config[:depth], config[:breadth], config[:text])
  xml_doc = generate_xml(config[:depth], config[:breadth], config[:text])

  puts "Document sizes: UDON=#{udon_doc.bytesize}B  YAML=#{yaml_doc.bytesize}B  XML=#{xml_doc.bytesize}B"
  puts

  # Get counts first
  udon_events = Udon.parse(udon_doc)
  udon_stats = traverse_udon_events(udon_events)

  yaml_data = YAML.safe_load(yaml_doc)
  yaml_stats = traverse_yaml(yaml_data)

  rexml_doc = REXML::Document.new(xml_doc)
  rexml_stats = traverse_rexml(rexml_doc)

  noko_stats = nil
  if HAS_NOKOGIRI
    noko_doc = Nokogiri::XML(xml_doc)
    noko_stats = traverse_nokogiri(noko_doc)
  end

  puts "Structure counts:"
  puts "  %-16s elements=%-4d attrs=%-4d text_bytes=%-6d library_calls=%d" % ["UDON:", udon_stats[:elements], udon_stats[:attrs], udon_stats[:text_bytes], udon_stats[:calls]]
  puts "  %-16s elements=%-4d attrs=%-4d text_bytes=%-6d library_calls=%d" % ["YAML:", yaml_stats[:elements], yaml_stats[:attrs], yaml_stats[:text_bytes], yaml_stats[:calls]]
  puts "  %-16s elements=%-4d attrs=%-4d text_bytes=%-6d library_calls=%d" % ["XML (REXML):", rexml_stats[:elements], rexml_stats[:attrs], rexml_stats[:text_bytes], rexml_stats[:calls]]
  puts "  %-16s elements=%-4d attrs=%-4d text_bytes=%-6d library_calls=%d" % ["XML (Nokogiri):", noko_stats[:elements], noko_stats[:attrs], noko_stats[:text_bytes], noko_stats[:calls]] if noko_stats
  puts

  results = []

  udon_result = run_benchmark("UDON (native)", config[:iters]) do
    events = Udon.parse(udon_doc)
    traverse_udon_events(events)
  end
  udon_result[:elements] = udon_stats[:elements]
  results << udon_result

  yaml_result = run_benchmark("YAML (Psych)", config[:iters]) do
    data = YAML.safe_load(yaml_doc)
    traverse_yaml(data)
  end
  yaml_result[:elements] = yaml_stats[:elements]
  results << yaml_result

  rexml_result = run_benchmark("XML (REXML)", [config[:iters], 10].min) do
    doc = REXML::Document.new(xml_doc)
    traverse_rexml(doc)
  end
  rexml_result[:elements] = rexml_stats[:elements]
  results << rexml_result

  if HAS_NOKOGIRI
    noko_result = run_benchmark("XML (Nokogiri)", config[:iters]) do
      doc = Nokogiri::XML(xml_doc)
      traverse_nokogiri(doc)
    end
    noko_result[:elements] = noko_stats[:elements]
    results << noko_result
  end

  puts "Results (parse + full traversal):"
  puts

  fastest = results.min_by { |r| r[:avg] }

  results.each do |r|
    elem_rate = format_rate(r[:elements], r[:avg])
    time = format_time(r[:avg])
    slower = r[:avg] / fastest[:avg]
    slower_str = slower > 1.1 ? " (#{slower.round(1)}x slower)" : " (fastest)"

    puts "  %-20s %12s  %12s elem/s%s" % [r[:name], time, elem_rate, slower_str]
  end
  puts
end

puts "=" * 78
puts "Summary"
puts "=" * 78
puts
puts "Elements/second measures semantic parsing speed (apples-to-apples)."
puts "Full traversal ensures lazy parsers (Nokogiri) are fully evaluated."
puts
