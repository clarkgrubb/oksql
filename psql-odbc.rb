#!/usr/bin/env ruby

require 'rubygems'
require 'odbc'
require 'pp'
require 'readline'

raise "usage: collector.rb NZUSER NZPASSWORD" unless ARGV.size == 2

DSN = 'NZSQL'

$user = ARGV[0]
pw = ARGV[1]
db = ODBC::Environment.new().connect(DSN, $user, pw)

def getline
  line = ''
  while part = Readline.readline(line.size > 0 ? "#{$user}-> " : "#{$user}=> ", true)
    line += part + "\n"
    return line if /;\s*\Z/.match(line)
  end
end

while line = getline
  stmt = db.run(line)
  #pp (stmt.methods() - Object.methods).sort()
  pp stmt.columns
  loop do
    row = stmt.fetch()
    break unless row
    pp row
  end
  stmt.drop()
end


