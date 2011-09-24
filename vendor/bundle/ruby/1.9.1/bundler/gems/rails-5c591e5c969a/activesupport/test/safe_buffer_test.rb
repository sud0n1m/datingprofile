require 'abstract_unit'
begin
  require 'psych'
rescue LoadError
end

require 'active_support/core_ext/string/inflections'
require 'yaml'

class SafeBufferTest < ActiveSupport::TestCase
  def setup
    @buffer = ActiveSupport::SafeBuffer.new
  end

  test "Should look like a string" do
    assert @buffer.is_a?(String)
    assert_equal "", @buffer
  end

  test "Should escape a raw string which is passed to them" do
    @buffer << "<script>"
    assert_equal "&lt;script&gt;", @buffer
  end

  test "Should NOT escape a safe value passed to it" do
    @buffer << "<script>".html_safe
    assert_equal "<script>", @buffer
  end

  test "Should not mess with an innocuous string" do
    @buffer << "Hello"
    assert_equal "Hello", @buffer
  end

  test "Should not mess with a previously escape test" do
    @buffer << ERB::Util.html_escape("<script>")
    assert_equal "&lt;script&gt;", @buffer
  end

  test "Should be considered safe" do
    assert @buffer.html_safe?
  end

  test "Should return a safe buffer when calling to_s" do
    new_buffer = @buffer.to_s
    assert_equal ActiveSupport::SafeBuffer, new_buffer.class
  end

  test "Should be converted to_yaml" do
    str  = 'hello!'
    buf  = ActiveSupport::SafeBuffer.new str
    yaml = buf.to_yaml

    assert_match(/^--- #{str}/, yaml)
    assert_equal 'hello!', YAML.load(yaml)
  end

  test "Should work in nested to_yaml conversion" do
    str  = 'hello!'
    data = { 'str' => ActiveSupport::SafeBuffer.new(str) }
    yaml = YAML.dump data
    assert_equal({'str' => str}, YAML.load(yaml))
  end

  test "Should work with underscore" do
    str = "MyTest".html_safe.underscore
    assert_equal "my_test", str
  end

  test "Should not return safe buffer from gsub" do
    altered_buffer = @buffer.gsub('', 'asdf')
    assert_equal 'asdf', altered_buffer
    assert !altered_buffer.html_safe?
  end

  test "Should not return safe buffer from gsub!" do
    @buffer.gsub!('', 'asdf')
    assert_equal 'asdf', @buffer
    assert !@buffer.html_safe?
  end

  test "Should escape dirty buffers on add" do
    dirty = @buffer
    clean = "hello".html_safe
    @buffer.gsub!('', '<>')
    assert_equal "hello&lt;&gt;", clean + @buffer
  end

  test "Should concat as a normal string when dirty" do
    dirty = @buffer
    clean = "hello".html_safe
    @buffer.gsub!('', '<>')
    assert_equal "<>hello", @buffer + clean
  end

  test "Should preserve dirty? status on copy" do
    @buffer.gsub!('', '<>')
    assert !@buffer.dup.html_safe?
  end

  test "Should raise an error when safe_concat is called on dirty buffers" do
    @buffer.gsub!('', '<>')
    assert_raise ActiveSupport::SafeBuffer::SafeConcatError do
      @buffer.safe_concat "BUSTED"
    end
  end
end
