//! Native Ruby extension for UDON parsing.
//!
//! Maps udon-core events directly to Ruby hashes.

use magnus::{function, prelude::*, Error, RArray, RHash, RString, Ruby, Symbol};
use udon_core::{Event, ParseErrorCode, Parser};

/// Create a span hash { start: n, end: n }.
fn span_to_hash(span: &std::ops::Range<usize>) -> RHash {
    let hash = RHash::new();
    let _ = hash.aset(Symbol::new("start"), span.start as i64);
    let _ = hash.aset(Symbol::new("end"), span.end as i64);
    hash
}

/// Convert content bytes to Ruby string.
fn content_to_rstring(content: &std::borrow::Cow<'_, [u8]>) -> RString {
    RString::from_slice(content.as_ref())
}

/// Convert a UDON Event to a Ruby hash.
fn event_to_ruby_hash(ruby: &Ruby, event: &Event) -> RHash {
    let hash = RHash::new();

    match event {
        // ========== Bracket Events (Start/End pairs) ==========

        Event::ElementStart { span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("element_start"));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span));
        }

        Event::ElementEnd { span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("element_end"));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span));
        }

        Event::EmbeddedStart { span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("embedded_start"));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span));
        }

        Event::EmbeddedEnd { span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("embedded_end"));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span));
        }

        Event::DirectiveStart { span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("directive_start"));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span));
        }

        Event::DirectiveEnd { span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("directive_end"));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span));
        }

        Event::ArrayStart { span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("array_start"));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span));
        }

        Event::ArrayEnd { span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("array_end"));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span));
        }

        Event::FreeformStart { span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("freeform_start"));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span));
        }

        Event::FreeformEnd { span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("freeform_end"));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span));
        }

        Event::CommentStart { span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("comment_start"));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span));
        }

        Event::CommentEnd { span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("comment_end"));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span));
        }

        // ========== Content Events ==========

        Event::Name { content, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("name"));
            let _ = hash.aset(Symbol::new("content"), content_to_rstring(content));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span));
        }

        Event::Text { content, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("text"));
            let _ = hash.aset(Symbol::new("content"), content_to_rstring(content));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span));
        }

        Event::Attr { content, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("attr"));
            let _ = hash.aset(Symbol::new("content"), content_to_rstring(content));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span));
        }

        Event::StringValue { content, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("string_value"));
            let _ = hash.aset(Symbol::new("content"), content_to_rstring(content));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span));
        }

        Event::BareValue { content, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("bare_value"));
            let _ = hash.aset(Symbol::new("content"), content_to_rstring(content));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span));
        }

        Event::BoolTrue { content, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("bool_true"));
            let _ = hash.aset(Symbol::new("content"), content_to_rstring(content));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span));
        }

        Event::BoolFalse { content, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("bool_false"));
            let _ = hash.aset(Symbol::new("content"), content_to_rstring(content));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span));
        }

        Event::Nil { content, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("nil"));
            let _ = hash.aset(Symbol::new("content"), content_to_rstring(content));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span));
        }

        Event::Integer { content, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("integer"));
            let _ = hash.aset(Symbol::new("content"), content_to_rstring(content));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span));
        }

        Event::Float { content, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("float"));
            let _ = hash.aset(Symbol::new("content"), content_to_rstring(content));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span));
        }

        Event::Rational { content, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("rational"));
            let _ = hash.aset(Symbol::new("content"), content_to_rstring(content));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span));
        }

        Event::Complex { content, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("complex"));
            let _ = hash.aset(Symbol::new("content"), content_to_rstring(content));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span));
        }

        Event::Interpolation { content, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("interpolation"));
            let _ = hash.aset(Symbol::new("content"), content_to_rstring(content));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span));
        }

        Event::Reference { content, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("reference"));
            let _ = hash.aset(Symbol::new("content"), content_to_rstring(content));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span));
        }

        Event::RawContent { content, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("raw_content"));
            let _ = hash.aset(Symbol::new("content"), content_to_rstring(content));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span));
        }

        Event::Raw { content, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("raw"));
            let _ = hash.aset(Symbol::new("content"), content_to_rstring(content));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span));
        }

        Event::Warning { content, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("warning"));
            let _ = hash.aset(Symbol::new("content"), content_to_rstring(content));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span));
        }

        // ========== Error Event ==========

        Event::Error { code, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("error"));
            let _ = hash.aset(Symbol::new("code"), Symbol::new(error_code_name(code)));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span));
        }
    }

    hash
}

/// Get error code name as string.
fn error_code_name(code: &ParseErrorCode) -> &'static str {
    match code {
        ParseErrorCode::UnexpectedEof => "unexpected_eof",
        ParseErrorCode::UnexpectedChar => "unexpected_char",
        ParseErrorCode::Unclosed => "unclosed",
        ParseErrorCode::UnclosedStringValue => "unclosed_string_value",
        ParseErrorCode::UnclosedArray => "unclosed_array",
        ParseErrorCode::UnclosedFreeform => "unclosed_freeform",
        ParseErrorCode::UnclosedText => "unclosed_text",
        ParseErrorCode::UnclosedInterpolation => "unclosed_interpolation",
        ParseErrorCode::NoTabs => "no_tabs",
    }
}

/// Parse UDON input and return an array of event hashes.
fn parse(ruby: &Ruby, input: RString) -> Result<RArray, Error> {
    let input_bytes = unsafe { input.as_slice() };

    let result = RArray::new();

    Parser::new(input_bytes).parse(|event| {
        let hash = event_to_ruby_hash(ruby, &event);
        let _ = result.push(hash);
    });

    Ok(result)
}

/// Initialize the Ruby extension.
#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let module = ruby.define_module("UdonNative")?;
    module.define_singleton_method("parse", function!(parse, 1))?;
    Ok(())
}
