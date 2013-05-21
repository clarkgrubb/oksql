require 'test/unit'
require File.dirname(__FILE__) + '/oksql.rb'

DSN = ENV['OKSQL_TEST_DSN']
unless DSN
  raise Exception.new("OKSQL_TEST_DSN env variable not set")
end
PSQL = Psql.new(DSN)

class PsqlTest < Test::Unit::TestCase

  def setup
  end

  def test_01
    assert(true)
  end

end
