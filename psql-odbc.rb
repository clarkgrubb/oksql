#!/usr/bin/env ruby

require 'rubygems'
require 'highline/import'
require 'odbc'
require 'optparse'
require 'pp'
require 'readline'
require File.dirname(__FILE__) + '/sql_parse.rb'

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
  class InvalidCommand < Exception; attr_accessor :command; end
  
  attr_accessor :user, :password, :dsn, :connection, :output

  SQL_COMMAND = Command.new('sql',
                            //,
                            '',
                            lambda { |psql, sql| psql.execute_sql(sql) })

  INVALID_COMMAND = Command.new('invalid',
                                //,
                                '',
                                lambda { |psql, cmd| psql.output.puts "Invalid Command #{cmd}. Try \\? for help."})
  
  #FIXME: improve regexes to eliminate /cd, /d, /o pairs

  META_COMMANDS = []
  
  [[
    'c',
    /\s*\\c\s+(\S+)/,
    '\c <dsn>        connect to new data source name',
    lambda { |psql, dsn| psql.connect(dsn) }
   ],
   [
    'cd',
    /\s*\\cd\s+([^ \t;]+)/,
    '\cd <dir>       change the current working directory',
    lambda { |psql, dir| Dir.chdir(dir) }
   ],
   [
    'cd',
    /\s*\\cd\b/,
    nil,
    lambda { |psql| Dir.chdir(ENV['HOME']) }
   ],
   [
    'd',
    /^\s*\\d\s+([^ \t;]+)/,
    '\d <table>      describe table (or view, index, sequence)',
    lambda { |psql, table| psql.describe_table(table.upcase) }
   ],
   [
    'd',
    /^\s*\\d\b/,
    nil,
    lambda { |psql| psql.describe_tables() }
   ],
   [
    'o',
    /^\s*\\o\s+(\|.+|[^ \t;]+)/,
    '\o [file]       send all query results to [file], or |pipe',
    lambda { |psql, file| psql.redirect_output(file) }
   ],
   [
    'o',
    /^\s*\\o\b/,
    nil,
    lambda { |psql| psql.output = $stdout }
   ],
   [
    'q',
    /^\s*\\q\b/,
    '\q              quit',
    lambda { |psql| raise PsqlQuit.new }
   ],
   [
    '?',
    /^\s*\\\?/,
    nil,
    lambda { |psql| psql.help }
   ]
  ].each { |a| META_COMMANDS << Command.new(*a) }
  
  # FIXME: Netezza specific
  
  DESCRIBE_TABLE_SQL = 
    "select column_name as \"Column\", type_name as \"Type\", case nullable when 0 then '' else 'not null' end as \"Modifiers\" from _v_sys_columns where table_name = ? order by ordinal_position;"

  DESCRIBE_TABLES_SQL =
    "select database, objname as name, objtype as \"type\", owner from _v_sys_relation where objtype in ( 'TABLE', 'VIEW', 'SEQUENCE' ) order by 2;"
  
  def initialize(args)
    user = nil
    get_options(args)
    self.output = $stdout
    @parser = SqlParse.new()
  end

  def help
    META_COMMANDS.each do |cmd|
      output.puts cmd.help if cmd.help
    end
  end
  
  def connect(dsn=nil)
    self.connection = ODBC::Environment.new().connect(dsn || DSN, user, password)
  end

  def redirect_output(file)
    md = /^\s*\|(.+)$/.match(file)
    if md
      cmd = md[1]
      self.output = IO.popen(cmd, mode='w')
    else
      self.output = File.open(file,'w')
    end
  end
  
  def get_options(args)
    opts = OptionParser.new
    opts.on("-d", "--dsn DSN") { |d| self.dsn = d }
    opts.on("-U", "--username USER") { |u| self.user = u }
    opts.on("-w", "--password") { self.password = get_password() }
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
    output.puts " " + display_me.join(' | ')
  end

  def print_bar(widths)
    display_me = widths.map { |w| '-' * w }
    output.puts "-" + display_me.join('-+-') + "-"
  end
  
  def print_header(columns, widths)
    print_array(columns.map {|c| c.name}, widths)
    print_bar(widths)
  end

  def print_footer(stmt)
    label = stmt.nrows == 1 ? 'row' : 'rows'
    output.puts "(#{stmt.nrows} #{label})"
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
    output.puts
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
      $stderr.puts e.to_s
    ensure
      stmt.drop() if stmt
    end
  end

  def describe_table(table)
    execute_sql(DESCRIBE_TABLE_SQL, table) do |stmt, sql, *bind_vars|
      if stmt.nrows == 0
        output.puts "Did not find any relation named \"#{table}\"."
      else
        # FIXME: measure to center this nicely:
        output.puts "       Table \"#{table}\""
        print_rows(stmt, :suppress_footer => true)
      end
    end
  end

  def describe_tables
    execute_sql(DESCRIBE_TABLES_SQL) do |stmt, sql|
      if stmt.nrows == 0
        output.puts "No relations found."
      else
        # FIXME: center title
        output.puts "      List of relations"
        print_rows(stmt)
      end
    end
  end
  
  def get_metacommand(line)
    META_COMMANDS.each do |cmd|
      md = cmd.regex.match(line)
      if md
        return cmd, md.captures, md.post_match
      end
    end
    md = /\s*(\S+)/.match(line)
    bad_command =  md ? md[1] : '?'
    return SQL_COMMAND, [bad_command], line
  end

  def get_parsed_line
    line = ''
    continuation_char = '='
    while part = Readline.readline("#{user}#{continuation_char}> ", true)
      line += part + "\n"
      stmts = @parser.parse(line)
      return stmts if not stmts.last.open?
      continuation_char = stmts.last.open_delimiter || '-'
    end
  end
  
  def get_command_arguments_pairs
    pairs = []
    stmts = get_parsed_line || []
    stmts.each do |stmt|
      if :meta_command == stmt.keyword
        cmd, args, unused_args = get_metacommand(stmt.raw)
        pairs << [cmd, args]
      else
        pairs << [SQL_COMMAND, [stmt.raw]]
      end
    end
    pairs
  end
  
  def repl
    loop do
      begin
        pairs = get_command_arguments_pairs()
        break if pairs.empty?
        pairs.each do |cmd, args|
          cmd.action.call(self, *args)
        end
      rescue Interrupt
        output.puts
        next
      rescue InvalidCommand => e
        $stderr.puts "Invalid command #{e.command}.  Try \\? for help."
      rescue PsqlQuit
        break
      end
    end
  end
  
end

if $0 == __FILE__
  psql = Psql.new(ARGV)
  psql.connect(psql.dsn)
  psql.repl()
end
