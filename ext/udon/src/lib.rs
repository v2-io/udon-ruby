//! Native Ruby extension for UDON parsing.
//!
//! This creates Ruby objects directly without JSON serialization,
//! providing the fastest possible Ruby integration.
//!
//! Returns streaming events as an array of hashes, matching the
//! SAX-style event model from udon-core.

use magnus::{
    function,
    prelude::*,
    Error, RArray, RHash, RString, Ruby, Symbol,
};
use udon_core::{StreamingParser, StreamingEvent, ChunkSlice, ChunkArena};

/// Resolve a ChunkSlice to bytes using the arena, then convert to Ruby String.
fn slice_to_rstring(arena: &ChunkArena, slice: ChunkSlice) -> RString {
    match arena.resolve(slice) {
        Some(bytes) => RString::from_slice(bytes),
        None => RString::new(""),
    }
}

/// Create a span hash { start: n, end: n }.
fn span_to_hash(start: u32, end: u32) -> RHash {
    let hash = RHash::new();
    let _ = hash.aset(Symbol::new("start"), start as i64);
    let _ = hash.aset(Symbol::new("end"), end as i64);
    hash
}

/// Convert a UDON StreamingEvent to a Ruby hash.
///
/// Returns streaming events matching the udon-core StreamingEvent model:
/// - ElementStart { name, span }
/// - ElementEnd { span }
/// - Attribute { key, span }
/// - Value events (NilValue, BoolValue, IntegerValue, etc.)
/// - ArrayStart/ArrayEnd
/// - Text, Comment, RawContent
/// - DirectiveStart/End, Interpolation
/// - Error
fn event_to_ruby_hash(ruby: &Ruby, arena: &ChunkArena, event: &StreamingEvent) -> RHash {
    let hash = RHash::new();

    match event {
        // ========== Structure Events ==========

        StreamingEvent::ElementStart { name, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("element_start"));
            let _ = hash.aset(
                Symbol::new("name"),
                name.map(|n| slice_to_rstring(arena, n).as_value())
                    .unwrap_or_else(|| ruby.qnil().as_value()),
            );
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        StreamingEvent::ElementEnd { span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("element_end"));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        StreamingEvent::EmbeddedStart { name, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("embedded_start"));
            let _ = hash.aset(
                Symbol::new("name"),
                name.map(|n| slice_to_rstring(arena, n).as_value())
                    .unwrap_or_else(|| ruby.qnil().as_value()),
            );
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        StreamingEvent::EmbeddedEnd { span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("embedded_end"));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        // ========== Attribute Events ==========

        StreamingEvent::Attribute { key, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("attribute"));
            let _ = hash.aset(Symbol::new("key"), slice_to_rstring(arena, *key));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        // ========== Value Events ==========

        StreamingEvent::ArrayStart { span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("array_start"));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        StreamingEvent::ArrayEnd { span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("array_end"));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        StreamingEvent::NilValue { span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("nil_value"));
            let _ = hash.aset(Symbol::new("value"), ruby.qnil());
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        StreamingEvent::BoolValue { value, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("bool_value"));
            let _ = hash.aset(Symbol::new("value"), *value);
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        StreamingEvent::IntegerValue { value, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("integer_value"));
            let _ = hash.aset(Symbol::new("value"), ruby.integer_from_i64(*value));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        StreamingEvent::FloatValue { value, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("float_value"));
            let _ = hash.aset(Symbol::new("value"), ruby.float_from_f64(*value));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        StreamingEvent::RationalValue { numerator, denominator, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("rational_value"));
            // Return as string "num/denom" - Ruby can convert with Rational()
            let _ = hash.aset(
                Symbol::new("value"),
                RString::new(&format!("{}/{}", numerator, denominator)),
            );
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        StreamingEvent::ComplexValue { real, imag, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("complex_value"));
            // Return as string "real+imagi" - Ruby can convert with Complex()
            let _ = hash.aset(
                Symbol::new("value"),
                RString::new(&format!("{}+{}i", real, imag)),
            );
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        StreamingEvent::StringValue { value, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("string_value"));
            let _ = hash.aset(Symbol::new("value"), slice_to_rstring(arena, *value));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        StreamingEvent::QuotedStringValue { value, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("quoted_string_value"));
            let _ = hash.aset(Symbol::new("value"), slice_to_rstring(arena, *value));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        // ========== Content Events ==========

        StreamingEvent::Text { content, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("text"));
            let _ = hash.aset(Symbol::new("content"), slice_to_rstring(arena, *content));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        StreamingEvent::Comment { content, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("comment"));
            let _ = hash.aset(Symbol::new("content"), slice_to_rstring(arena, *content));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        StreamingEvent::RawContent { content, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("raw_content"));
            let _ = hash.aset(Symbol::new("content"), slice_to_rstring(arena, *content));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        // ========== Directive Events ==========

        StreamingEvent::DirectiveStart { name, namespace, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("directive_start"));
            let _ = hash.aset(Symbol::new("name"), slice_to_rstring(arena, *name));
            let _ = hash.aset(
                Symbol::new("namespace"),
                namespace
                    .map(|n| slice_to_rstring(arena, n).as_value())
                    .unwrap_or_else(|| ruby.qnil().as_value()),
            );
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        StreamingEvent::DirectiveEnd { span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("directive_end"));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        StreamingEvent::InlineDirective(data) => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("inline_directive"));
            let _ = hash.aset(Symbol::new("name"), slice_to_rstring(arena, data.name));
            let _ = hash.aset(
                Symbol::new("namespace"),
                data.namespace
                    .map(|n| slice_to_rstring(arena, n).as_value())
                    .unwrap_or_else(|| ruby.qnil().as_value()),
            );
            let _ = hash.aset(Symbol::new("content"), slice_to_rstring(arena, data.content));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(data.span.start, data.span.end));
        }

        StreamingEvent::Interpolation { expression, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("interpolation"));
            let _ = hash.aset(Symbol::new("expression"), slice_to_rstring(arena, *expression));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        // ========== Reference Events ==========

        StreamingEvent::IdReference { id, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("id_reference"));
            let _ = hash.aset(Symbol::new("id"), slice_to_rstring(arena, *id));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        StreamingEvent::AttributeMerge { id, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("attribute_merge"));
            let _ = hash.aset(Symbol::new("id"), slice_to_rstring(arena, *id));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        // ========== Block Events ==========

        StreamingEvent::FreeformStart { span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("freeform_start"));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        StreamingEvent::FreeformEnd { span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("freeform_end"));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        // ========== Error Events ==========

        StreamingEvent::Error { code, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("error"));
            let _ = hash.aset(Symbol::new("message"), RString::new(code.message()));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }
    }

    hash
}

/// Parse UDON input and return an array of event hashes.
fn parse(ruby: &Ruby, input: RString) -> Result<RArray, Error> {
    let input_bytes = unsafe { input.as_slice() };

    // Create streaming parser with reasonable capacity
    let capacity = (input_bytes.len() / 50).max(64);
    let mut parser = StreamingParser::new(capacity);

    // Feed input and finish
    parser.feed(input_bytes);
    parser.finish();

    // Collect all events
    let result = RArray::new();
    while let Some(event) = parser.read() {
        result.push(event_to_ruby_hash(ruby, parser.arena(), &event))?;
    }

    Ok(result)
}

/// Initialize the Ruby extension.
#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let module = ruby.define_module("UdonNative")?;
    module.define_singleton_method("parse", function!(parse, 1))?;
    Ok(())
}
