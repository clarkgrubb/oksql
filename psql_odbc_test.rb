require 'test/unit'
require File.dirname(__FILE__) + '/psql-odbc.rb'

DSN = ENV['PSQL_ODBC_TEST_DSN']
unless DSN
  raise Exception.new("PSQL_ODBC_TEST_DSN env variable not set")
end
PSQL = Psql.new(DSN)

class PsqlTest < Test::Unit::TestCase

  def setup
  end

  def test_01
    assert(true)
  end

end
