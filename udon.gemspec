# frozen_string_literal: true

require_relative "lib/udon/version"

Gem::Specification.new do |spec|
  spec.name = "udon"
  spec.version = Udon::VERSION
  spec.authors = ["Joseph Wecker"]
  spec.email = ["joseph.wecker@gmail.com"]

  spec.summary = "High-performance UDON parser with native Rust extension"
  spec.description = <<~DESC
    Native Ruby bindings for the UDON (Universal Document & Object Notation) parser.
    Uses a high-performance Rust core with zero-copy parsing and SIMD acceleration.
  DESC
  spec.homepage = "https://github.com/josephwecker/udon-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir[
    "lib/**/*.rb",
    "ext/**/*.{rs,toml,rb,lock}",
    "sig/**/*.rbs",
    "LICENSE",
    "README.md",
    "CHANGELOG.md"
  ]
  spec.require_paths = ["lib"]
  spec.extensions = ["ext/udon/extconf.rb"]

  # rb_sys is the bridge between Ruby's native extension system and Rust
  spec.add_dependency "rb_sys", "~> 0.9"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rake-compiler", "~> 1.2"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "benchmark-ips", "~> 2.0"
end
