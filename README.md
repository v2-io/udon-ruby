# Udon

High-performance UDON (Universal Document & Object Notation) parser for Ruby.

Uses a native Rust extension for maximum performance:
- ~1.3 GiB/s raw Rust parsing throughput
- Zero-copy event emission
- Streaming event model (no DOM overhead)

## Installation

Add to your Gemfile:

```ruby
gem 'udon'
```

Then run:

```bash
bundle install
```

This requires Rust to be installed (for compilation). Install via [rustup](https://rustup.rs/).

## Usage

```ruby
require 'udon'

# Parse a UDON document
events = Udon.parse(<<~UDON)
  |article[my-post].featured
    :title "Hello, World!"
    :published true

    |section
      This is the first paragraph.

      |ul
        |li First item
        |li Second item
UDON

# Process events
events.each do |event|
  case event[:type]
  when :element_start
    puts "Element started"
  when :name
    puts "Name: #{event[:content]}"
  when :attr
    puts "Attr: #{event[:content]}"
  when :string_value, :bare_value
    puts "Value: #{event[:content]}"
  when :text
    puts "Text: #{event[:content].strip}"
  when :element_end
    puts "Element ended"
  end
end
```

## Event Types

Each event is a Hash with `:type` and `:span` keys. Content events also have `:content`.

**Bracket events (start/end pairs):**
- `:element_start`, `:element_end`
- `:embedded_start`, `:embedded_end`
- `:directive_start`, `:directive_end`
- `:array_start`, `:array_end`
- `:freeform_start`, `:freeform_end`
- `:comment_start`, `:comment_end`

**Content events (have `:content`):**
- `:name` - element/directive name
- `:text` - text content
- `:attr` - attribute name
- `:string_value` - quoted string value
- `:bare_value` - unquoted value
- `:bool_true`, `:bool_false` - boolean values
- `:nil` - nil/null value
- `:integer`, `:float`, `:rational`, `:complex` - numeric values
- `:interpolation` - interpolation expression
- `:reference` - reference content
- `:raw_content`, `:raw` - raw content

**Error events:**
- `:error` - has `:code` instead of `:content`

## Performance

Benchmarks comparing UDON against other Ruby parsers (parse + full traversal):

| Parser | Elements/sec | vs Psych |
|--------|-------------|----------|
| **UDON** | 150-175K | **2x faster** |
| Psych (YAML) | 80-90K | baseline |
| REXML (XML) | 50-60K | 0.6x |
| Nokogiri (XML) | 350-380K | 4x faster |

UDON's streaming model emits ~12 events per element (Name, Attr, Value, Text, etc.),
while DOM parsers like Nokogiri build the tree in C++ and create fewer Ruby objects.
This makes UDON competitive with Psych while providing streaming benefits (no DOM
memory overhead, early termination, etc.).

Run benchmarks yourself:

```bash
bundle exec rake bench
```

## Development

```bash
# Install dependencies
bundle install

# Compile native extension
bundle exec rake compile

# Run tests
bundle exec rake test

# Run benchmarks
bundle exec rake bench
```

## License

MIT
