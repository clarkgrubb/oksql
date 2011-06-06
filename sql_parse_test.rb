# coding: utf-8
require 'test/unit'
require File.dirname(__FILE__) + '/sql_parse.rb'
require 'pp'

class SqlParseTest < Test::Unit::TestCase

  def setup
    @sql = SqlParse.new()
  end

  # simple test
  def test_01
    stmts = @sql.parse(" select 'foo'; ")
    assert_equal(1, stmts.size)
    stmt = stmts[0]
    assert_equal(:select, stmt.keyword)
    assert(!stmt.open?)
    assert_equal(" select 'foo';", stmt.raw)
  end

  # two statements
  def test_02
    stmts = @sql.parse(" select 'foo'; insert into foo values ( 3 ); ")
    assert_equal(2, stmts.size)
    
    stmt1 = stmts[0]
    assert_equal(:select, stmt1.keyword)
    assert(!stmt1.open?)
    assert_equal(" select 'foo';", stmt1.raw)

    stmt2 = stmts[1]
    assert_equal(:insert, stmt2.keyword)
    assert(!stmt2.open?)
    assert_equal(" insert into foo values ( 3 );", stmt2.raw)
  end

  # all the keywords
  def test_03
    tests = {
      " select 'foo';" => :select,
      " insert into foo values ( 3 );" => :insert,
      " update foo set a = 3;" => :update,
      " delete from foo where a = 3;" => :delete,
      " truncate foo;" => :truncate,
      " create table foo ( a int ); " => :create,
      " alter table foo add column b text; " => :alter,
      " drop table foo; " => :drop,
      " grant all on foo to bar; " => :grant,
      " revoke all on foo from bar; " => :revoke,
    }

    tests.each do |input, keyword|
      stmts = @sql.parse(input)
      assert_equal(1, stmts.size)
      stmt = stmts.first
      assert_equal(keyword, stmt.keyword)
    end
  end

  # keyword is case insensitive
  def test_04
    stmts = @sql.parse(" SELECT * from foo; ")
    assert_equal(1, stmts.size)
    stmt = stmts.first
    assert_equal(:select, stmt.keyword)
    assert_equal(" SELECT * from foo;", stmt.raw)
  end
  
  # open string
  def test_05
    stmts = @sql.parse(" select 'foo bar")
    assert_equal(1, stmts.size)
    stmt = stmts.first
    assert(stmt.open?)
    assert_equal("'", stmt.open_delimiter)
    assert_equal(:select, stmt.keyword)
  end
  
  # open quoted name
  def test_06
    stmts = @sql.parse(' create table "foo bar')
    assert_equal(1, stmts.size)
    stmt = stmts.first
    assert(stmt.open?)
    assert_equal('"', stmt.open_delimiter)
    assert_equal(:create, stmt.keyword)
  end

  # open parens
  def test_07
    stmts = @sql.parse(' create table foo ( a int')
    assert_equal(1, stmts.size)
    stmt = stmts.first
    assert(stmt.open?)
    assert_equal('(', stmt.open_delimiter)
    assert_equal(:create, stmt.keyword)
  end
    
  # statement with balanced parens
  def test_08
    stmts = @sql.parse("select * from foo where a in ( select b from bar );")
    assert_equal(1, stmts.size)
    stmt = stmts.first
    assert(!stmt.open?)
    assert_equal(:select, stmt.keyword)
  end
    
  # two statements, last is open string
  def test_09
    stmts = @sql.parse(" select 7; insert into foo ")
    assert_equal(2, stmts.size)

    stmt1 = stmts[0]
    assert(!stmt1.open?)
    assert_equal(:select, stmt1.keyword)
    assert_equal(" select 7;", stmt1.raw)

    stmt2 = stmts[1]
    assert(stmt2.open?)
    assert_nil(stmt2.open_delimiter)
    assert_equal(:insert, stmt2.keyword)
    assert_equal(" insert into foo", stmt2.raw)
  end

  # unknown keyword
  def test_10
    stmts = @sql.parse(" 1 + 7;")
    assert_equal(1, stmts.size)
    stmt = stmts[0]
    assert(!stmt.open?)
    assert_equal(:unknown, stmt.keyword)
    assert_equal(" 1 + 7;", stmt.raw)
  end

  # meta command
  def test_11
    stmts = @sql.parse(' \d foo ')
    assert_equal(1, stmts.size)
    stmt = stmts[0]
    assert(!stmt.open?)
    assert_equal(:meta_command, stmt.keyword)
    assert_equal(' \d foo ', stmt.raw)
  end

  # meta command and sql command
  def test_12
    stmts = @sql.parse(' \d foo ; select \'foo\'; ')
    assert_equal(2, stmts.size)

    stmt1 = stmts[0]
    assert(!stmt1.open?)
    assert_equal(:meta_command, stmt1.keyword)
    assert_equal(' \d foo ;', stmt1.raw)

    stmt2 = stmts[1]
    assert(!stmt2.open?)
    assert_equal(:select, stmt2.keyword)
    assert_equal(" select 'foo';", stmt2.raw)
  end
  
end
