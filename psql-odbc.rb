#!/usr/bin/env ruby

require 'rubygems'
require 'highline/import'
require 'odbc'
require 'optparse'
require 'pp'
require 'readline'
require File.dirname(__FILE__) + '/sql_parse.rb'

DSN = 'PRD_EDW'
HBAR = '*' * 50
ROWS_FOR_ALIGNMENT = 100

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

  attr_accessor :user, :password, :dsn, :connection, :output, :align_columns

  SQL_LAMBDA = lambda do |psql, sql, keyword, object|
    psql.execute_sql(sql, keyword, object)
  end

  SQL_COMMAND = Command.new('sql',
                            //,
                            '',
                            SQL_LAMBDA)

  INVALID_LAMBDA = lambda do |psql, cmd|
    psql.output.puts "Invalid Command #{cmd}. Try \\? for help."
  end

  INVALID_COMMAND = Command.new('invalid',
                                //,
                                '',
                                INVALID_LAMBDA)

  #FIXME: improve regexes to eliminate /cd, /d, /o pairs

  META_COMMANDS = []

  [[
    'a',
    /^\s*\\a\b/,
    '\a              toggle whether column output is aligned',
    lambda { |psql| psql.toggle_alignment }
   ],
   [
    'c',
    /^\s*\\c\s+(\S+)/,
    '\c <dsn>        connect to new data source name',
    lambda { |psql, dsn| psql.connect(dsn) }
   ],
   [
    'cd',
    /^\s*\\cd\s+([^ \t;]+)/,
    '\cd <dir>       change the current working directory',
    lambda { |psql, dir| Dir.chdir(dir) }
   ],
   [
    'cd',
    /^\s*\\cd\b/,
    nil,
    lambda { |psql| Dir.chdir(ENV['HOME']) }
   ],
   [
    'd',
    /^\s*\\d\s+([^ \t;]+)/,
    '\d <table>      describe table (or view, sequence)',
    lambda { |psql, table| psql.describe_table(table.upcase) }
   ],
   [
    'd',
    /^\s*\\d\b/,
    nil,
    lambda { |psql| psql.describe_tables() }
   ],
   [
    'f',
    /^\s*\\f\s+(.*)/,
    '\f [sep]        set or show field separator',
    lambda { |psql, fs| psql.set_field_separator(fs) }
   ],
   [
    'f',
    /^\s*\\f\b/,
    nil,
    lambda { |psql| psql.show_field_separator }
   ],
   [
    'i',
    /^\s*\\i\s*(\S+)/,
    '\i <file>       read input from file and execute it',
    lambda { |psql, file| psql.execute_file(file) }
   ],
   [
    'i',
    /^\s*\\i\b/,
    nil,
    lambda { |psql| $stderr.puts "\\i: missing required argument" }
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
    't',
    /^\s*\\t\b/,
    '\t              toggle whether to show only rows',
    lambda { |psql| psql.toggle_show_only_rows }
   ],
   [
    '!',
    /^\s*\\\!(.*)/,
    '\! [cmd]        shell escape or command',
    lambda { |psql, cmd| system(cmd) }
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
    @show_only_rows = false
    @align_columns = true
    @field_separator = '|'
  end

  def toggle_show_only_rows
    @show_only_rows = ! @show_only_rows
    if @show_only_rows
      output.puts "Showing only tuples."
    else
      output.puts "Tuples only is off."
    end
  end

  def toggle_alignment
    @align_columns = ! @align_columns
    output.puts "Output format is #{@align_columns ? '' : 'un'}aligned."
  end

  def show_field_separator
    output.puts "Field separator is \"#{@field_separator}\"."
  end

  def set_field_separator(fs)
    if fs == '\t'
      # HACK: this is not psql behavior
      @field_separator = "\t"
    elsif fs[0..0] == "'"
      lexer = SqlLex.new()
      token, value, _, _ = lexer.lex_string(fs[1..-1])
      if :open == token
        output.puts "unterminated quoted string"
      else
        @field_separator = value
      end
    else
      @field_separator = fs.split.first
      @field_separator = '' if @field_separator.nil?
    end
    show_field_separator
  end

  def help
    META_COMMANDS.each do |cmd|
      output.puts cmd.help if cmd.help
    end
  end

  def connect(dsn=nil)
    begin
      self.connection = ODBC::Environment.new().connect(dsn || DSN, user, password)
    rescue ODBC::Error => e
      self.connection = nil
      $stderr.puts "failed to connect to dsn: #{dsn}: #{e}"
    end
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
    if @align_columns
      separator = ' ' + @field_separator + ' '
      pad = ' '
    else
      separator = @field_separator
      pad = ''
    end
    display_me = []
    a.each_with_index do |o, i|
      display_me << "%-#{widths[i]}s" % o.to_s
    end
    output.puts pad + display_me.join(separator)
  end

  def print_bar(widths)
    display_me = widths.map { |w| '-' * w }
    output.puts "-" + display_me.join('-+-') + "-"
  end

  def print_header(columns, widths)
    print_array(columns.map {|c| c.name}, widths)
    print_bar(widths) if @align_columns
  end

  def print_footer(stmt)
    label = stmt.nrows == 1 ? 'row' : 'rows'
    output.puts "(#{stmt.nrows} #{label})"
  end

  class Rows

    def initialize(stmt, psql)
      @stmt = stmt
      @display_widths = nil
      @rows_for_alignment = nil
      @psql = psql
    end

    def display_widths
      @display_widths ||= get_display_widths
      @display_widths
    end

    def columns
      (0...@stmt.ncols).map {|i| @stmt.column(i) }
    end

    def prefetch_rows
      if @stmt.nrows <= ROWS_FOR_ALIGNMENT
        @rows_for_alignment = @stmt.fetch_all()
      else
        @rows_for_alignment = []
        ROWS_FOR_ALIGNMENT.times do
          @rows_for_alignment << @stmt.fetch()
        end
      end
      @rows_for_alignment || []
    end

    def each
      @rows_for_alignment ||= prefetch_rows
      @rows_for_alignment.each do |row|
        yield(row)
      end

      while row = @stmt.fetch()
        yield(row)
      end
    end

    def get_display_widths
      if !@psql.align_columns
        a = columns.map {|c| 0 }
      else
        a = columns.map {|c| c.name.size }
        @rows_for_alignment ||= prefetch_rows
        @rows_for_alignment.each do |row|
          row.each_with_index do |val, i|
            if val.to_s.size > a[i]
              a[i] = val.to_s.size
            end
          end
        end
      end
      @display_widths = a
    end
  end

  def _print_rows(stmt, opts={})
    rows = Rows.new(stmt, self)
    print_header(rows.columns, rows.display_widths) unless @show_only_rows
    rows.each do |row|
      print_array(row, rows.display_widths)
    end
    print_footer(stmt) unless opts[:suppress_footer] or @show_only_rows
    output.puts
    output.flush
  end

  def _page_rows(stmt, opts={})
    # less options:
    #   -X suppress init and denit
    #   -S chop long lines
    #   -F don't page if less than a page
    #
    ENV['LESS'] = 'FX' # equivalent to: less -FX
    pager = ENV['PAGER'] || 'less'
    f = IO.popen(pager, 'w')
    begin
      self.output = f
      _print_rows(stmt, opts)
    rescue Errno::EPIPE
    ensure
      self.output = $stdout
      f.close
    end
  end

  def print_rows(stmt, opts={})
    if self.output == $stdout and $stdout.isatty
      _page_rows(stmt, opts)
    else
      _print_rows(stmt, opts)
    end
  end

  def select?(line)
    /\A\s*select/i.match(line)
  end

  def with?(line)
    /\A\s*with/i.match(line)
  end

  def explain?(line)
    /\A\s*explain/i.match(line)
  end

  def show?(line)
    /\A\s*show/i.match(line)
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

  def print_status(stmt, keyword, object)
    object = object.strip.upcase
    case keyword
    when :insert
      # FIXME: if a single row is inserted into a table with an OID
      #        the first number is supposed to be the OID.
      output.puts "INSERT 0 #{stmt.nrows}"
    when :update
      output.puts "UPDATE #{stmt.nrows}"
    when :delete
      output.puts "DELETE #{stmt.nrows}"
    when :create
      output.puts "CREATE #{object}"
    when :drop
      output.puts "DROP #{object}"
    when :alter
      output.puts "ALTER #{object}"
    when :truncate
      output.puts "TRUNCATE #{object}"
    when :grant
      output.puts "GRANT"
    when :revoke
      output.puts "REVOKE"
    end
  end

  def execute_sql(sql, keyword, object, *bind_vars)
    if connection.nil?
      $stderr.puts "not connected to a db; use \c to connect"
      return
    end
    begin
      stmt = connection.run(sql, *bind_vars)
      #inspect_statement(stmt)
      if block_given?
        yield(stmt, sql, *bind_vars)
      else
        if select?(sql) or explain?(sql) or show?(sql) or with?(sql)
          print_rows(stmt)
        end
      end
      print_status(stmt, keyword, object)
    rescue ODBC::Error => e
      $stderr.puts e.to_s
    ensure
      stmt.drop() if stmt
    end
  end

  def describe_table(table)
    execute_sql(DESCRIBE_TABLE_SQL, :unknown, '',  table) do |stmt, sql, *bind_vars|
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
    execute_sql(DESCRIBE_TABLES_SQL, :unknown, '') do |stmt, sql|
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
    return INVALID_COMMAND, [bad_command], line
  end

  def get_raw_line(continuation_char)
    if $stdin.tty?
      Readline.readline("#{user}#{continuation_char}> ", true)
    else
      $stdin.gets
    end
  end

  def get_parsed_line
    line = ''
    continuation_char = '='
    while part = get_raw_line(continuation_char)
      line += part + "\n"
      stmts = @parser.parse(line)
      raise PsqlQuit.new() if stmts.empty? and not $stdin.tty?
      return stmts if stmts.empty? or not stmts.last.open?
      continuation_char = stmts.last.open_delimiter || '-'
    end
    raise PsqlQuit.new()
  end

  def get_command_arguments_pairs(input)
    pairs = []
    stmts = input || []
    stmts.each do |stmt|
      if :meta_command == stmt.keyword
        cmd, args, unused_args = get_metacommand(stmt.raw)
        pairs << [cmd, args]
      else
        pairs << [SQL_COMMAND, [stmt.raw, stmt.keyword, stmt.object]]
      end
    end
    pairs
  end

  def execute_file(file)
    begin
      input = File.open(file).read()
    rescue Errno::ENOENT
      $stderr.puts "#{file}: No such file or directory"
    end
    pairs = get_command_arguments_pairs(@parser.parse(input))
    pairs.each do |cmd, args|
      cmd.action.call(self, *args)
    end
  end

  def repl
    loop do
      begin
        pairs = get_command_arguments_pairs(get_parsed_line)
        next if pairs.empty?
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
