# frozen_string_literal: true

require "minitest/autorun"
require "udon"

class UdonTest < Minitest::Test
  def test_version
    assert_match(/\d+\.\d+\.\d+/, Udon::VERSION)
  end

  def test_parse_simple_element
    events = Udon.parse("|div Hello\n")

    assert_kind_of Array, events
    assert events.size >= 2

    # First should be element_start
    start_event = events.find { |e| e[:type] == :element_start }
    assert start_event
    assert_equal "div", start_event[:name]

    # Should have text
    text_event = events.find { |e| e[:type] == :text }
    assert text_event
    assert_includes text_event[:content], "Hello"
  end

  def test_parse_element_with_id
    events = Udon.parse("|div[my-id] Content\n")

    start_event = events.find { |e| e[:type] == :element_start }
    assert start_event
    assert_equal "my-id", start_event[:id]
  end

  def test_parse_element_with_classes
    events = Udon.parse("|div.class-a.class-b Content\n")

    start_event = events.find { |e| e[:type] == :element_start }
    assert start_event
    assert_includes start_event[:classes], "class-a"
    assert_includes start_event[:classes], "class-b"
  end

  def test_parse_inline_attributes
    # Note: Currently inline attributes are parsed, indented attributes
    # on separate lines are a TODO for the parser
    events = Udon.parse("|div :title Hello :count 42\n")

    attrs = events.select { |e| e[:type] == :attribute }
    assert_equal 2, attrs.size

    title_attr = attrs.find { |a| a[:key] == "title" }
    assert title_attr
    assert_equal "Hello", title_attr[:value]

    count_attr = attrs.find { |a| a[:key] == "count" }
    assert count_attr
    # Value is returned as the parsed type - for unquoted integers, it's Integer
    # (if parser recognizes it) or String otherwise
    assert_includes [42, "42"], count_attr[:value]
  end

  def test_parse_empty_input
    events = Udon.parse("")
    assert_kind_of Array, events
    assert_equal 0, events.size
  end

  def test_parse_comment
    events = Udon.parse("; This is a comment\n")

    comment = events.find { |e| e[:type] == :comment }
    assert comment
    assert_includes comment[:content], "This is a comment"
  end

  def test_events_have_spans
    events = Udon.parse("|div Hello\n")

    events.each do |event|
      assert event[:span], "Event #{event[:type]} should have span"
      assert_kind_of Hash, event[:span]
      assert event[:span][:start]
      assert event[:span][:end]
    end
  end
end
