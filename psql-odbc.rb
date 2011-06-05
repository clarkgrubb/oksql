#!/usr/bin/env ruby

require 'rubygems'
require 'highline/import'
require 'odbc'
require 'optparse'
require 'pp'
require 'readline'

DSN = 'NZSQL'
HBAR = '*' * 50
MAX_ROWS = 100

class Command

  attr_accessor :name, :regex, :help, :action
  
  def initialize(n, r, h, a)
    self.name = n
    self.regex = r
    self.help = h
    self.action = a
  end
  
end

class Psql

  class PsqlQuit < Exception; end
  
  attr_accessor :user, :password, :database, :connection

  SQL_COMMAND = Command.new('sql',
                            //,
                            '',
                            lambda { |psql, sql| psql.execute_sql(sql) })
  
  META_COMMANDS = []
  META_COMMANDS <<
    Command.new('d',
                /^\s*\\d\s+(\S+)/,
                "\d <table>      describe table (or view, index, sequence, synonym)",
                lambda { |psql, table| psql.describe_table(table.upcase) }
                )
  META_COMMANDS <<
    Command.new('q',
                /^\s*\\q\b/,
                "\q              quit",
                lambda { |psql| raise PsqlQuit.new }
                )

  
  DESCRIBE_TABLE_SQL = 
    "select column_name as \"Column\", type_name as \"Type\", case nullable when 0 then '' else 'not null' end as \"Modifiers\" from _v_sys_columns where table_name = ? order by ordinal_position;"
  
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

  def print_array(a, widths)
    display_me = []
    a.each_with_index do |o, i|
      display_me << "%-#{widths[i]}s" % o.to_s
    end
    puts " " + display_me.join(' | ')
  end

  def print_bar(widths)
    display_me = widths.map { |w| '-' * w }
    puts "-" + display_me.join('-+-') + "-"
  end
  
  def print_header(columns, widths)
    print_array(columns.map {|c| c.name}, widths)
    print_bar(widths)
  end

  def print_footer(stmt)
    label = stmt.nrows == 1 ? 'row' : 'rows'
    puts "(#{stmt.nrows} #{label})"
  end

  def get_columns(stmt)
    (0...stmt.ncols).map {|i| stmt.column(i) }
  end
    
  def get_rows(stmt)
    if stmt.nrows <= MAX_ROWS
      rows = stmt.fetch_all()
    else
      rows = []
      MAX_ROWS.times do
        rows << stmt.fetch()
      end
    end
    rows
  end

  def get_display_widths(columns, rows)
    a = columns.map {|c| c.name.size }
    rows.each do |row|
      row.each_with_index do |val, i|
        if val.to_s.size > a[i]
          a[i] = val.to_s.size
        end
      end
    end
    a
  end
  
  def print_rows(stmt, opts={})
    columns = get_columns(stmt)
    rows = get_rows(stmt) || []
    widths = get_display_widths(columns, rows)
    print_header(columns, widths)
    rows.each do |row|
      print_array(row, widths)
    end
    print_footer(stmt) unless opts[:suppress_footer]
    puts
  end

  def select?(line)
    /^\s*select/i.match(line)
  end

  def inspect_methods(o, name)
    puts name + ' METHODS'
    puts HBAR
    pp (o.methods() - Object.methods).sort()
    puts
  end

  def inspect_attributes(o, name)
    puts name + ' ATTRIBUTES'
    puts HBAR
    pp o
    puts
  end
  
  def inspect_statement(stmt)
    inspect_methods(stmt, "STATEMENT")
    inspect_attributes(stmt.ncols, "NCOLS")
    inspect_attributes(stmt.nrows, "NROWS")
    inspect_attributes(stmt.count, "COUNT")
    (0...stmt.ncols).each do |c|
      inspect_attributes(stmt.column(c), "COLUMN #{c}")
    end
  end

  def execute_sql(sql, *bind_vars)
    begin
      stmt = connection.run(sql, *bind_vars)
      # inspect_statement(stmt)
      if block_given?
        yield(stmt, sql, *bind_vars)
      else
        print_rows(stmt) if select?(sql)
      end
    rescue ODBC::Error => e
      puts e.to_s
    ensure
      stmt.drop() if stmt
    end
  end

  def get_metacommand(line)
    META_COMMANDS.each do |cmd|
      md = cmd.regex.match(line)
      if md
        return cmd, md.captures, md.post_match
      end
    end
    nil
  end

  def describe_table(table)
    execute_sql(DESCRIBE_TABLE_SQL, table) do |stmt, sql, *bind_vars|
      if stmt.nrows == 0
        puts "Did not find any relation named \"#{table}\"."
      else
        # FIXME: measure to center this nicely:
        puts "       Table \"#{table}\""
        print_rows(stmt, :suppress_footer => true)
      end
    end
  end
  
  def get_command
    line = ''
    while part = Readline.readline(line.size > 0 ? "#{$user}-> " : "#{$user}=> ", true)
    line += part + "\n"
      cmd, args, rest = get_metacommand(line)
      if cmd
        return cmd, args, rest
      end
      if /;\s*\Z/.match(line)
        return SQL_COMMAND, [line], nil
      end
    end
    nil
  end
  
  def repl
    loop do
      begin
        cmd, args, line = get_command()
        break unless cmd
        cmd.action.call(self, *args)
      rescue Interrupt
        puts
        next
      rescue PsqlQuit
        break
      end
    end
  end
  
end

if $0 == __FILE__
  psql = Psql.new(ARGV)
  psql.connect()
  psql.repl()
end
