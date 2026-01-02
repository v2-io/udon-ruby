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

    # Should have element_start followed by name
    assert_equal :element_start, events[0][:type]
    assert_equal :name, events[1][:type]
    assert_equal "div", events[1][:content]

    # Should have text
    text_event = events.find { |e| e[:type] == :text }
    assert text_event
    assert_includes text_event[:content], "Hello"
  end

  def test_parse_element_with_id
    # New model: ElementStart, Name, Attr("id"), BareValue("my-id"), ...
    events = Udon.parse("|div[my-id] Content\n")

    assert_equal :element_start, events[0][:type]
    assert_equal :name, events[1][:type]
    assert_equal "div", events[1][:content]

    # ID comes as Attr("id") followed by BareValue
    id_attr = events.find { |e| e[:type] == :attr && e[:content] == "id" }
    assert id_attr, "Should have id attribute"

    id_attr_idx = events.index(id_attr)
    id_value = events[id_attr_idx + 1]
    assert_equal :bare_value, id_value[:type]
    assert_equal "my-id", id_value[:content]
  end

  def test_parse_element_with_classes
    # New model: each .class emits Attr("class"), BareValue
    events = Udon.parse("|div.class-a.class-b Content\n")

    assert_equal :element_start, events[0][:type]
    assert_equal :name, events[1][:type]
    assert_equal "div", events[1][:content]

    # Classes come as Attr("class") followed by BareValue pairs
    class_attrs = events.select { |e| e[:type] == :attr && e[:content] == "class" }
    assert_equal 2, class_attrs.size, "Should have 2 class attributes"

    # Verify the class values
    class_values = []
    class_attrs.each do |attr|
      idx = events.index(attr)
      value_event = events[idx + 1]
      assert_equal :bare_value, value_event[:type]
      class_values << value_event[:content]
    end
    assert_includes class_values, "class-a"
    assert_includes class_values, "class-b"
  end

  def test_parse_inline_attributes
    events = Udon.parse("|div :title Hello :count 42\n")

    # Find attributes by content
    title_attr = events.find { |e| e[:type] == :attr && e[:content] == "title" }
    assert title_attr, "Should have :title attribute"

    title_idx = events.index(title_attr)
    title_value = events[title_idx + 1]
    assert_equal :bare_value, title_value[:type]
    assert_equal "Hello", title_value[:content]

    count_attr = events.find { |e| e[:type] == :attr && e[:content] == "count" }
    assert count_attr, "Should have :count attribute"

    count_idx = events.index(count_attr)
    count_value = events[count_idx + 1]
    assert_equal :integer, count_value[:type]
    assert_equal "42", count_value[:content]
  end

  def test_parse_indented_attributes
    events = Udon.parse("|div\n  :title Hello\n  :count 42\n")

    title_attr = events.find { |e| e[:type] == :attr && e[:content] == "title" }
    assert title_attr, "Should have :title attribute"

    title_idx = events.index(title_attr)
    title_value = events[title_idx + 1]
    assert_equal :bare_value, title_value[:type]
    assert_equal "Hello", title_value[:content]

    count_attr = events.find { |e| e[:type] == :attr && e[:content] == "count" }
    assert count_attr, "Should have :count attribute"

    count_idx = events.index(count_attr)
    count_value = events[count_idx + 1]
    assert_equal :integer, count_value[:type]
    assert_equal "42", count_value[:content]
  end

  def test_parse_empty_input
    events = Udon.parse("")
    assert_kind_of Array, events
    assert_equal 0, events.size
  end

  def test_parse_comment
    events = Udon.parse("; This is a comment\n")

    # New model: CommentStart, Text (comment content), CommentEnd
    comment_start = events.find { |e| e[:type] == :comment_start }
    assert comment_start, "Should have comment_start"

    # Find text within comment
    text_event = events.find { |e| e[:type] == :text }
    assert text_event
    assert_includes text_event[:content], "This is a comment"

    comment_end = events.find { |e| e[:type] == :comment_end }
    assert comment_end, "Should have comment_end"
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
    tags_attr = events.find { |e| e[:type] == :attr && e[:content] == "tags" }
    assert tags_attr, "Should have :tags attribute"

    # Next should be ArrayStart
    tags_idx = events.index(tags_attr)
    array_start = events[tags_idx + 1]
    assert_equal :array_start, array_start[:type]

    # Then values (as bare_value in new model)
    values = events.select { |e| e[:type] == :bare_value }
    value_strings = values.map { |v| v[:content] }
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
    disabled_attr = events.find { |e| e[:type] == :attr && e[:content] == "disabled" }
    assert disabled_attr, "Should have :disabled attribute"

    # Next should be BoolTrue for flag attributes
    disabled_idx = events.index(disabled_attr)
    bool_value = events[disabled_idx + 1]
    assert_equal :bool_true, bool_value[:type]
  end

  def test_parse_quoted_string_attribute
    events = Udon.parse("|div :title \"Hello World\"\n")

    # Find the :title attribute
    title_attr = events.find { |e| e[:type] == :attr && e[:content] == "title" }
    assert title_attr, "Should have :title attribute"

    # Next should be StringValue
    title_idx = events.index(title_attr)
    quoted_value = events[title_idx + 1]
    assert_equal :string_value, quoted_value[:type]
    assert_equal "Hello World", quoted_value[:content]
  end

  def test_parse_element_suffix
    # Suffix emits as Attr("?") + BoolTrue
    events = Udon.parse("|field?\n")

    assert_equal :element_start, events[0][:type]
    assert_equal :name, events[1][:type]
    assert_equal "field", events[1][:content]

    suffix_attr = events.find { |e| e[:type] == :attr && e[:content] == "?" }
    assert suffix_attr, "Should have ? suffix attribute"

    suffix_idx = events.index(suffix_attr)
    suffix_value = events[suffix_idx + 1]
    assert_equal :bool_true, suffix_value[:type]
  end

  def test_parse_interpolation
    events = Udon.parse("|p Hello !{{name}}!\n")

    interp = events.find { |e| e[:type] == :interpolation }
    assert interp, "Should have interpolation"
    assert_equal "name", interp[:content]
  end

  def test_parse_nested_elements
    events = Udon.parse("|parent\n  |child\n")

    # Should have two element_start events
    starts = events.select { |e| e[:type] == :element_start }
    assert_equal 2, starts.size

    # And two element_end events
    ends = events.select { |e| e[:type] == :element_end }
    assert_equal 2, ends.size

    # Names should be parent and child
    names = events.select { |e| e[:type] == :name }.map { |e| e[:content] }
    assert_includes names, "parent"
    assert_includes names, "child"
  end
end
