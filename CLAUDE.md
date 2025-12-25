# CLAUDE.md - Agent Guidelines for udon-ruby

This is the Ruby gem for UDON parsing. It wraps the libudon Rust library using
rb_sys and magnus for native Ruby integration.

## Implementation Plan

**See `~/src/udon/implementation-phase-2.md` for the comprehensive roadmap.**

Current state: Basic event-based parsing works. Phase 2 will add:
- Lazy tree API (Ruby objects created on access, not upfront)
- Streaming API with ring buffer
- World-class error messages

## Architecture

```
udon-ruby/
├── ext/udon/           # Rust native extension
│   ├── Cargo.toml      # Dependencies on udon-core, magnus, rb-sys
│   ├── extconf.rb      # Ruby extension build config
│   └── src/lib.rs      # Magnus bindings
├── lib/
│   ├── udon.rb         # Main entry point
│   └── udon/
│       └── version.rb
├── test/               # Minitest tests
├── Gemfile
├── Rakefile
└── udon.gemspec
```

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

## Performance Target

Goal is to beat or match Nokogiri in "realistic" benchmarks that include
traversing the full parsed structure. The native extension avoids JSON
serialization overhead by creating Ruby objects directly in Rust.

## Testing

Tests should verify:
1. Parsing produces correct events
2. Unicode handling works properly
3. Error events are emitted for malformed input
4. Performance meets targets

## Specification

The UDON specification lives in a separate repo:
https://github.com/josephwecker/udon
