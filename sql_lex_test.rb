# coding: utf-8
require 'test/unit'
require File.dirname(__FILE__) + '/sql_lex.rb'
require 'pp'

class SqlLexTest < Test::Unit::TestCase

  def setup
    @sql = SqlLex.new()
  end

  def test_01
    token, value, raw, rest = @sql.lex(" select 'foo'; ")
    assert_equal(:keyword_or_variable, token)
    assert_equal('select', value)
    assert_equal(' select', raw)
    assert_equal(" 'foo'; ", rest)
  end

  # comment takes everything to the end of the line
  def test_02
    token, value, raw, rest = @sql.lex_comment(" -- this is a comment; select 'foo'; ")
    assert_equal(:comment, token)
    assert_equal("-- this is a comment; select 'foo'; ", value)
    assert_equal(" -- this is a comment; select 'foo'; ", raw)
    assert_equal("", rest)
  end

  # comment doesn't take stuff after the end of the line
  def test_03
    token, value, raw, rest = @sql.lex_comment(" -- this is a comment\n select 'foo'; ")
    assert_equal(:comment, token)
    assert_equal("-- this is a comment\n", value)
    assert_equal(" -- this is a comment\n", raw)
    assert_equal(" select 'foo'; ", rest)
  end

  # lex skips comment
  def test_04
    token, value, raw, rest = @sql.lex(" -- this is a comment\n select 'foo'; ")
    assert_equal(:keyword_or_variable, token)
    assert_equal("select", value)
    assert_equal(" select", raw)
    assert_equal(" 'foo'; ", rest)
  end

  # single quote string
  def test_05
    token, value, raw, rest = @sql.lex(" 'foo bar'; ")
    assert_equal(:string, token)
    assert_equal("foo bar", value)
    assert_equal(" 'foo bar'", raw)
    assert_equal("; ", rest)
  end

  # single quote string with escaped character
  def test_06
    token, value, raw, rest = @sql.lex(" 'foo''bar'; ")
    assert_equal(:string, token)
    assert_equal("foo'bar", value)
    assert_equal(" 'foo''bar'", raw)
    assert_equal("; ", rest)
  end

  # string with newline
  def test_07
    token, value, raw, rest = @sql.lex(" 'foo\nbar'; ")
    assert_equal(:string, token)
    assert_equal("foo\nbar", value)
    assert_equal(" 'foo\nbar'", raw)
    assert_equal("; ", rest)
  end
  
  # open string
  def test_08
    token, value, raw, rest = @sql.lex(" 'foo bar baz")
    assert_equal(:open, token)
    assert_equal("'", value)
    assert_equal(" 'foo bar baz", raw)
    assert_equal("'foo bar baz", rest)
  end
  
  # quoted variable
  def test_09
    token, value, raw, rest = @sql.lex(' "foo bar"; ')
    assert_equal(:quoted_variable, token)
    assert_equal("foo bar", value)
    assert_equal(' "foo bar"', raw)
    assert_equal("; ", rest)
  end

  # quoted variable with escaped character
  def test_10
    token, value, raw, rest = @sql.lex(' "foo""bar"; ')
    assert_equal(:quoted_variable, token)
    assert_equal('foo"bar', value)
    assert_equal(' "foo""bar"', raw)
    assert_equal("; ", rest)
  end

  # quoted variable with newline
  def test_11
    token, value, raw, rest = @sql.lex(" \"foo\nbar\"; ")
    assert_equal(:quoted_variable, token)
    assert_equal("foo\nbar", value)
    assert_equal(" \"foo\nbar\"", raw)
    assert_equal("; ", rest)
  end
  
  # open quoted variable
  def test_12
    token, value, raw, rest = @sql.lex(' "foo bar baz')
    assert_equal(:open, token)
    assert_equal('"', value)
    assert_equal(' "foo bar baz', raw)
    assert_equal('"foo bar baz', rest)
  end

  # operators
  def test_13
    tests = {
      " + 17; " => ['+', ' +', ' 17; '],
      " - 17; " => ['-', ' -', ' 17; '],
      " * 17; " => ['*', ' *', ' 17; '],
      " / 17; " => ['/', ' /', ' 17; '],
      " % 17; " => ['%', ' %', ' 17; '],
      " || 'foo' " => ['||', ' ||', " 'foo' "],
    }
    
    tests.each do |input, a|
      expected_value, expected_raw, expected_rest = a
      token, value, raw, rest = @sql.lex(input)
      assert_equal(:operator, token, "input: #{input}")
      assert_equal(expected_value, value, "input: #{input}")
      assert_equal(expected_raw, raw, "input: #{input}")
      assert_equal(expected_rest, rest, "input: #{input}")
    end
  end
  
  # positive integer, negative integer, zero
  def test_14
    tests = {
      " 17 + 3 " => ['17', ' 17', ' + 3 '],
      " -17 + 3 " => ['-17', ' -17', ' + 3 '],
      " 0 + 17 " => ['0', ' 0', ' + 17 '],
    }

    tests.each do |input, a|
      expected_value, expected_raw, expected_rest = a
      token, value, raw, rest = @sql.lex(input)
      assert_equal(:integer, token, "input: #{input}")
      assert_equal(expected_value, value, "input: #{input}")
      assert_equal(expected_raw, raw, "input: #{input}")
      assert_equal(expected_rest, rest, "input: #{input}")
    end

  end

  # float, negative float, no leading part, no trailing part
  def test_15
    tests = {
      " 39.7 + 4.2" => ['39.7', ' 39.7', ' + 4.2'],
      " -17.1 + 39" => ['-17.1', ' -17.1', ' + 39'],
      " .37 + 19" => ['.37', ' .37', ' + 19'],
      " -17. + 3" => ['-17.', ' -17.', ' + 3'],
    }
    
    tests.each do |input, a|
      expected_value, expected_raw, expected_rest = a
      token, value, raw, rest = @sql.lex(input)
      assert_equal(:float, token, "input: #{input}")
      assert_equal(expected_value, value, "input: #{input}")
      assert_equal(expected_raw, raw, "input: #{input}")
      assert_equal(expected_rest, rest, "input: #{input}")
    end
  end

  # open paren
  def test_16
    token, value, raw, rest = @sql.lex(" ( hello ) ")
    assert_equal(:open_paren, token)
    assert_equal('(', value)
    assert_equal(' (', raw)
    assert_equal(' hello ) ', rest)
  end
  
  # close paren
  def test_17
    token, value, raw, rest = @sql.lex(" ) ; ")
    assert_equal(:close_paren, token)
    assert_equal(')', value)
    assert_equal(' )', raw)
    assert_equal(' ; ', rest)
  end

  # semicolon
  def test_17
    token, value, raw, rest = @sql.lex(" ; select 'foo';")
    assert_equal(:semicolon, token)
    assert_equal(';', value)
    assert_equal(' ;', raw)
    assert_equal(" select 'foo';", rest)
  end

  # end: empty string
  def test_18
    token, value, raw, rest = @sql.lex('')
    assert_equal(:end, token)
    assert_nil(value)
    assert_equal('', raw)
    assert_nil(rest)
  end

  # end: whitespace
  def test_19
    token, value, raw, rest = @sql.lex(" \t\n ")
    assert_equal(:end, token)
    assert_nil(value)
    assert_equal(" \t\n ", raw)
    assert_nil(rest)
  end

  # stream
  def test_20
    test = [
            [:keyword_or_variable, "select", " select"],
            [:string, "foo", " 'foo'"],
            [:semicolon, ";", ";"],
            [:keyword_or_variable, "select", " select"],
            [:string, "bar", " 'bar'"],
            [:semicolon, ";", ";"],
            [:end, nil, ""]]
    
    s = @sql.stream(" select 'foo'; select 'bar';")
    assert_equal(test.size, s.size)
    test.each_with_index do |expected_a, i|
      a = s[i]
      assert_equal(expected_a.size, a.size, "elements at index #{i} not equal")
      expected_a.each_with_index do |expected, j|
        assert_equal(expected, a[j], "elements at index #{i} subindex #{j} not equal")
      end
    end
  end

  # meta_command
  def test_21
    token, value, raw, rest = @sql.lex(' \d foo')
    assert_equal(:meta_command, token)
    assert_equal('\d foo', value)
    assert_equal(' \d foo', raw)
    assert_equal('', rest)

  end

  # meta command and semicolon preceded by whitespace
  def test_22
    token, value, raw, rest = @sql.lex(' \d foo ; select \'foo\';')
    assert_equal(:meta_command, token)
    assert_equal('\d foo ;', value)
    assert_equal(' \d foo ;', raw)
    assert_equal(' select \'foo\';', rest)
  end
  

  # meta command and semicolon non preceded by whitespace
  def test_23
    token, value, raw, rest = @sql.lex(' \d foo; select \'foo\';')
    assert_equal(:meta_command, token)
    assert_equal('\d foo; select \'foo\';', value)
    assert_equal(' \d foo; select \'foo\';', raw)
    assert_equal('', rest)
  end

end
