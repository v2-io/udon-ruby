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
    # In streaming model: ElementStart, Attribute($id), StringValue, ElementEnd
    events = Udon.parse("|div[my-id] Content\n")

    start_event = events.find { |e| e[:type] == :element_start }
    assert start_event
    assert_equal "div", start_event[:name]

    # ID comes as Attribute("$id") followed by StringValue
    id_attr = events.find { |e| e[:type] == :attribute && e[:key] == "$id" }
    assert id_attr, "Should have $id attribute"

    # Find the value event after the $id attribute
    id_attr_idx = events.index(id_attr)
    id_value = events[id_attr_idx + 1]
    assert_equal :string_value, id_value[:type]
    assert_equal "my-id", id_value[:value]
  end

  def test_parse_element_with_classes
    # In streaming model: each .class emits Attribute($class), StringValue
    events = Udon.parse("|div.class-a.class-b Content\n")

    start_event = events.find { |e| e[:type] == :element_start }
    assert start_event
    assert_equal "div", start_event[:name]

    # Classes come as Attribute("$class") followed by StringValue pairs
    class_attrs = events.select { |e| e[:type] == :attribute && e[:key] == "$class" }
    assert_equal 2, class_attrs.size, "Should have 2 $class attributes"

    # Verify the class values
    class_values = []
    class_attrs.each do |attr|
      idx = events.index(attr)
      value_event = events[idx + 1]
      assert_equal :string_value, value_event[:type]
      class_values << value_event[:value]
    end
    assert_includes class_values, "class-a"
    assert_includes class_values, "class-b"
  end

  def test_parse_inline_attributes
    events = Udon.parse("|div :title Hello :count 42\n")

    # Find attributes by key
    title_attr = events.find { |e| e[:type] == :attribute && e[:key] == "title" }
    assert title_attr, "Should have :title attribute"

    title_idx = events.index(title_attr)
    title_value = events[title_idx + 1]
    assert_equal :string_value, title_value[:type]
    assert_equal "Hello", title_value[:value]

    count_attr = events.find { |e| e[:type] == :attribute && e[:key] == "count" }
    assert count_attr, "Should have :count attribute"

    count_idx = events.index(count_attr)
    count_value = events[count_idx + 1]
    # SPEC: Unquoted integers should be returned as Integer
    assert_equal :integer_value, count_value[:type], "Expected integer_value, got #{count_value[:type]}"
    assert_equal 42, count_value[:value], "Expected integer 42, got #{count_value[:value].inspect}"
  end

  def test_parse_indented_attributes
    # SPEC: Attributes can appear on indented lines after an element
    events = Udon.parse("|div\n  :title Hello\n  :count 42\n")

    # Find attributes by key
    title_attr = events.find { |e| e[:type] == :attribute && e[:key] == "title" }
    assert title_attr, "Should have :title attribute"

    title_idx = events.index(title_attr)
    title_value = events[title_idx + 1]
    assert_equal :string_value, title_value[:type]
    assert_equal "Hello", title_value[:value]

    count_attr = events.find { |e| e[:type] == :attribute && e[:key] == "count" }
    assert count_attr, "Should have :count attribute"

    count_idx = events.index(count_attr)
    count_value = events[count_idx + 1]
    assert_equal :integer_value, count_value[:type]
    assert_equal 42, count_value[:value]
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

  def test_parse_array_attribute
    events = Udon.parse("|div :tags [a b c]\n")

    # Find the :tags attribute
    tags_attr = events.find { |e| e[:type] == :attribute && e[:key] == "tags" }
    assert tags_attr, "Should have :tags attribute"

    # Next should be ArrayStart
    tags_idx = events.index(tags_attr)
    array_start = events[tags_idx + 1]
    assert_equal :array_start, array_start[:type]

    # Then values
    values = events.select { |e| e[:type] == :string_value }
    value_strings = values.map { |v| v[:value] }
    assert_includes value_strings, "a"
    assert_includes value_strings, "b"
    assert_includes value_strings, "c"

    # Then ArrayEnd
    array_end = events.find { |e| e[:type] == :array_end }
    assert array_end, "Should have array_end"
  end

  def test_parse_flag_attribute
    events = Udon.parse("|button :disabled\n")

    # Find the :disabled attribute
    disabled_attr = events.find { |e| e[:type] == :attribute && e[:key] == "disabled" }
    assert disabled_attr, "Should have :disabled attribute"

    # Next should be BoolValue(true) for flag attributes
    disabled_idx = events.index(disabled_attr)
    bool_value = events[disabled_idx + 1]
    assert_equal :bool_value, bool_value[:type]
    assert_equal true, bool_value[:value]
  end

  def test_parse_quoted_string_attribute
    events = Udon.parse("|div :title \"Hello World\"\n")

    # Find the :title attribute
    title_attr = events.find { |e| e[:type] == :attribute && e[:key] == "title" }
    assert title_attr, "Should have :title attribute"

    # Next should be QuotedStringValue
    title_idx = events.index(title_attr)
    quoted_value = events[title_idx + 1]
    assert_equal :quoted_string_value, quoted_value[:type]
    assert_equal "Hello World", quoted_value[:value]
  end

  def test_parse_element_suffix
    # Suffix emits as Attribute("?") + BoolValue(true)
    events = Udon.parse("|field?\n")

    start_event = events.find { |e| e[:type] == :element_start }
    assert start_event
    assert_equal "field", start_event[:name]

    suffix_attr = events.find { |e| e[:type] == :attribute && e[:key] == "?" }
    assert suffix_attr, "Should have ? suffix attribute"

    suffix_idx = events.index(suffix_attr)
    suffix_value = events[suffix_idx + 1]
    assert_equal :bool_value, suffix_value[:type]
    assert_equal true, suffix_value[:value]
  end
end
