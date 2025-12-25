# Udon

High-performance UDON (Universal Document & Object Notation) parser for Ruby.

Uses a native Rust extension for maximum performance:
- ~1.3 GiB/s raw parsing throughput
- Zero-copy event emission
- SIMD-accelerated scanning
- Direct Ruby object creation (no JSON serialization)

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
    puts "Start: #{event[:name]} id=#{event[:id]} classes=#{event[:classes]}"
  when :element_end
    puts "End"
  when :attribute
    puts "Attr: #{event[:key]} = #{event[:value]}"
  when :text
    puts "Text: #{event[:content].strip}"
  end
end
```

## Event Types

Each event is a Hash with a `:type` key and additional fields:

| Type | Fields |
|------|--------|
| `:element_start` | `name`, `id`, `classes`, `suffix`, `span` |
| `:element_end` | `span` |
| `:attribute` | `key`, `value`, `span` |
| `:text` | `content`, `span` |
| `:comment` | `content`, `span` |
| `:embedded_start` | `name`, `id`, `classes`, `span` |
| `:embedded_end` | `span` |
| `:directive_start` | `name`, `namespace`, `is_raw`, `span` |
| `:directive_end` | `span` |
| `:inline_directive` | `name`, `namespace`, `is_raw`, `content`, `span` |
| `:interpolation` | `expression`, `span` |
| `:raw_content` | `content`, `span` |
| `:error` | `message`, `span` |

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
