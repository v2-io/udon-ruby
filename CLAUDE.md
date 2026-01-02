# CLAUDE.md - Agent Guidelines for udon-ruby

This is the Ruby gem for UDON parsing. It wraps the libudon Rust library using
rb_sys and magnus for native Ruby integration.

## Current State

Uses the **phase-3 descent-generated parser** from libudon. The parser emits
callback-based events that are collected into Ruby hashes.

## Architecture

```
udon-ruby/
├── ext/udon/           # Rust native extension
│   ├── Cargo.toml      # Dependencies on udon-core, magnus, rb-sys
│   ├── extconf.rb      # Ruby extension build config
│   └── src/lib.rs      # Magnus bindings - maps Event -> Ruby hash
├── lib/
│   ├── udon.rb         # Main entry point
│   └── udon/
│       └── version.rb
├── test/               # Minitest tests
├── Gemfile
├── Rakefile
└── udon.gemspec
```

## Event Model

The parser emits events as Ruby hashes with `:type` and `:span` keys.
Content events also have `:content`, errors have `:code`.

Bracket events (start/end pairs):
- `:element_start`, `:element_end`
- `:embedded_start`, `:embedded_end`
- `:directive_start`, `:directive_end`
- `:array_start`, `:array_end`
- `:freeform_start`, `:freeform_end`
- `:comment_start`, `:comment_end`

Content events:
- `:name` - element/directive name
- `:text` - text content
- `:attr` - attribute name
- `:string_value`, `:bare_value` - values
- `:bool_true`, `:bool_false`, `:nil` - special values
- `:integer`, `:float`, `:rational`, `:complex` - numeric types
- `:interpolation`, `:reference`, `:raw_content`, `:raw`

## Build System

The gem uses rb_sys to bridge Ruby's native extension system and Rust/Cargo:

1. `extconf.rb` calls `create_rust_makefile`
2. rake-compiler invokes `cargo build`
3. The resulting .bundle/.so is placed in `lib/udon/`
4. Ruby loads it via `require "udon/udon"`

## Dependencies

The Rust extension depends on:
- **udon-core** (from libudon): Core parser
- **magnus**: Ruby bindings with Ruby 3.x support
- **rb-sys**: Low-level Ruby ABI bridge

## Development Workflow

```bash
# Install gems
bundle install

# Compile extension
bundle exec rake compile

# Run tests
bundle exec rake test

# Build gem
bundle exec rake build
```

## Dependency on libudon

Currently uses a local path for development:

```toml
udon-core = { path = "../../../libudon/udon-core" }
```

For release, this should change to:

```toml
udon-core = { git = "https://github.com/josephwecker/libudon.git" }
# or, after crates.io publish:
udon-core = "0.9"
```

## Specification

The UDON specification lives in a separate repo:
https://github.com/josephwecker/udon
