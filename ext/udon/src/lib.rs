//! Native Ruby extension for UDON parsing.
//!
//! This creates Ruby objects directly without JSON serialization,
//! providing the fastest possible Ruby integration.

use magnus::{
    function,
    prelude::*,
    Error, RArray, RHash, RString, Ruby, Symbol, Value,
};
use udon_core::{Event, Parser, Value as UdonValue};

/// Convert a byte slice to a Ruby String.
fn bytes_to_rstring(bytes: &[u8]) -> RString {
    RString::from_slice(bytes)
}

/// Convert a UDON Value to a Ruby value.
fn udon_value_to_ruby(ruby: &Ruby, value: &UdonValue) -> Value {
    match value {
        UdonValue::Nil => ruby.qnil().as_value(),
        UdonValue::Bool(b) => {
            if *b {
                ruby.qtrue().as_value()
            } else {
                ruby.qfalse().as_value()
            }
        }
        UdonValue::Integer(i) => ruby.integer_from_i64(*i).as_value(),
        UdonValue::Float(f) => ruby.float_from_f64(*f).as_value(),
        UdonValue::String(s) | UdonValue::QuotedString(s) => {
            bytes_to_rstring(s).as_value()
        }
        UdonValue::Rational { numerator, denominator } => {
            RString::new(&format!("{}/{}", numerator, denominator)).as_value()
        }
        UdonValue::Complex { real, imag } => {
            RString::new(&format!("{}+{}i", real, imag)).as_value()
        }
        UdonValue::List(_) => {
            RString::new("[list]").as_value()
        }
    }
}

/// Create a span hash { start: n, end: n }.
fn span_to_hash(start: u32, end: u32) -> RHash {
    let hash = RHash::new();
    let _ = hash.aset(Symbol::new("start"), start as i64);
    let _ = hash.aset(Symbol::new("end"), end as i64);
    hash
}

/// Convert a UDON event to a Ruby hash.
fn event_to_ruby_hash(ruby: &Ruby, event: &Event) -> RHash {
    let hash = RHash::new();

    match event {
        Event::ElementStart { name, id, classes, suffix, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("element_start"));
            let _ = hash.aset(
                Symbol::new("name"),
                name.map(|n| bytes_to_rstring(n).as_value())
                    .unwrap_or_else(|| ruby.qnil().as_value()),
            );
            let _ = hash.aset(
                Symbol::new("id"),
                id.as_ref()
                    .map(|v| udon_value_to_ruby(ruby, v))
                    .unwrap_or_else(|| ruby.qnil().as_value()),
            );
            let classes_arr = RArray::new();
            for class in classes {
                let _ = classes_arr.push(bytes_to_rstring(class));
            }
            let _ = hash.aset(Symbol::new("classes"), classes_arr);
            if let Some(s) = suffix {
                let _ = hash.aset(Symbol::new("suffix"), RString::new(&s.to_string()));
            }
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        Event::ElementEnd { span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("element_end"));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        Event::Attribute { key, value, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("attribute"));
            let _ = hash.aset(Symbol::new("key"), bytes_to_rstring(key));
            let _ = hash.aset(
                Symbol::new("value"),
                value
                    .as_ref()
                    .map(|v| udon_value_to_ruby(ruby, v))
                    .unwrap_or_else(|| ruby.qnil().as_value()),
            );
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        Event::Text { content, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("text"));
            let _ = hash.aset(Symbol::new("content"), bytes_to_rstring(content));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        Event::Comment { content, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("comment"));
            let _ = hash.aset(Symbol::new("content"), bytes_to_rstring(content));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        Event::Error { message, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("error"));
            let _ = hash.aset(Symbol::new("message"), RString::new(message));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        Event::EmbeddedStart { name, id, classes, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("embedded_start"));
            let _ = hash.aset(
                Symbol::new("name"),
                name.map(|n| bytes_to_rstring(n).as_value())
                    .unwrap_or_else(|| ruby.qnil().as_value()),
            );
            let _ = hash.aset(
                Symbol::new("id"),
                id.as_ref()
                    .map(|v| udon_value_to_ruby(ruby, v))
                    .unwrap_or_else(|| ruby.qnil().as_value()),
            );
            let classes_arr = RArray::new();
            for class in classes {
                let _ = classes_arr.push(bytes_to_rstring(class));
            }
            let _ = hash.aset(Symbol::new("classes"), classes_arr);
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        Event::EmbeddedEnd { span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("embedded_end"));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        Event::DirectiveStart { name, namespace, is_raw, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("directive_start"));
            let _ = hash.aset(Symbol::new("name"), bytes_to_rstring(name));
            let _ = hash.aset(
                Symbol::new("namespace"),
                namespace
                    .map(|n| bytes_to_rstring(n).as_value())
                    .unwrap_or_else(|| ruby.qnil().as_value()),
            );
            let _ = hash.aset(Symbol::new("is_raw"), *is_raw);
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        Event::DirectiveEnd { span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("directive_end"));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        Event::InlineDirective { name, namespace, is_raw, content, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("inline_directive"));
            let _ = hash.aset(Symbol::new("name"), bytes_to_rstring(name));
            let _ = hash.aset(
                Symbol::new("namespace"),
                namespace
                    .map(|n| bytes_to_rstring(n).as_value())
                    .unwrap_or_else(|| ruby.qnil().as_value()),
            );
            let _ = hash.aset(Symbol::new("is_raw"), *is_raw);
            let _ = hash.aset(Symbol::new("content"), bytes_to_rstring(content));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        Event::Interpolation { expression, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("interpolation"));
            let _ = hash.aset(Symbol::new("expression"), bytes_to_rstring(expression));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        Event::RawContent { content, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("raw_content"));
            let _ = hash.aset(Symbol::new("content"), bytes_to_rstring(content));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        Event::IdReference { id, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("id_reference"));
            let _ = hash.aset(Symbol::new("id"), bytes_to_rstring(id));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        Event::AttributeMerge { id, span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("attribute_merge"));
            let _ = hash.aset(Symbol::new("id"), bytes_to_rstring(id));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        Event::FreeformStart { span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("freeform_start"));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }

        Event::FreeformEnd { span } => {
            let _ = hash.aset(Symbol::new("type"), Symbol::new("freeform_end"));
            let _ = hash.aset(Symbol::new("span"), span_to_hash(span.start, span.end));
        }
    }

    hash
}

/// Parse UDON input and return an array of event hashes.
fn parse(ruby: &Ruby, input: RString) -> Result<RArray, Error> {
    let input_bytes = unsafe { input.as_slice() };

    let mut parser = Parser::new(input_bytes);
    let events = parser.parse();

    let result = RArray::new();
    for event in &events {
        result.push(event_to_ruby_hash(ruby, event))?;
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
