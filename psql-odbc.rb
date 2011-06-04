#!/usr/bin/env ruby

require 'rubygems'
require 'highline/import'
require 'odbc'
require 'optparse'
require 'pp'
require 'readline'

DSN = 'NZSQL'

class Psql

  attr_accessor :user, :password, :database, :connection
  
  def initialize(args)
    user = nil
    get_options(args)
  end

  def connect
    self.connection = ODBC::Environment.new().connect(DSN, user, password)
  end
  
  def get_options(args)
    opts = OptionParser.new
    opts.on("-d", "--dbname DBNAME") { |db| database = db }
    opts.on("-U", "--username USER") { |u| user = u }
    opts.on("-w", "--password") { password = get_password() }
    opts.parse(*args)
  end
  
  def get_password
    ask("Password: ") { |q| q.echo = false }
  end
  
  def get_line
    line = ''
    while part = Readline.readline(line.size > 0 ? "#{$user}-> " : "#{$user}=> ", true)
    line += part + "\n"
      return line if /;\s*\Z/.match(line)
    end
  end

  def print_header(stmt)
    # pp (stmt.columns.first.methods() - Object.methods()).sort()
    puts " " + stmt.columns.values.map { |c| "%-#{c.length}s" % c.name }.join(' | ') + " "
    puts "-" + stmt.columns.values.map { |c| "-" * c.length }.join('-+-') + "-"
  end

  def print_footer(stmt)
    label = stmt.rowsetsize == 1 ? 'row' : 'rows'
    puts "(#{stmt.rowsetsize} #{label})"
  end
  
  def print_rows(stmt)
    print_header(stmt)
    loop do
      row = stmt.fetch()
      break unless row
      puts " " + row.join(' | ') + " "
    end
    print_footer(stmt)
  end

  def select?(line)
    /^\s*select/i.match(line)
  end
  
  def execute_sql(line)
    begin
      stmt = connection.run(line)
      # pp (stmt.methods() - Object.methods).sort()
      # pp stmt.columns
      print_rows(stmt) if select?(line)
      stmt.drop()
    rescue ODBC::Error => e
      puts "ERROR: #{e}"
    end
  end
  
  def repl
    while line = get_line()
      execute_sql(line)
    end
  end
  
end

psql = Psql.new(ARGV)
psql.connect()
psql.repl()
