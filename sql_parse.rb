# coding: utf-8

require File.dirname(__FILE__) + '/sql_lex.rb'

class SqlParse

  class Statement

    attr_accessor :tokens, :values, :raw, :open_quote, :semicolon_terminated

    KEYWORDS = {
      'select' => :select,
      'insert' => :insert,
      'update' => :update,
      'delete' => :delete,
      'truncate' => :truncate,
      'create' => :create,
      'alter' => :alter,
      'drop' => :drop,
      'grant' => :grant,
      'revoke' => :revoke,
    }
    
    def initialize()
      @open = false
      @tokens = []
      @values = []
      @raw = ''
      @open_quote = nil
      @semicolon_terminated = false
      @keyword = nil
    end

    def keyword
      unless @keyword
        first_value = (values.first || '').downcase
        if :keyword_or_variable ==  tokens.first
          @keyword = KEYWORDS[first_value] || :unknown
        else
          @keyword = :unknown
        end
      end
      @keyword
    end
    
    def open?
      @open_quote or not @semicolon_terminated or not open_parens.empty?
    end

    def open_parens
      a = []
      tokens.each do |token|
        case token
        when :open_paren
          a << '('
        when :close_paren
          a.pop
        end
      end
      a
    end
    
    def open_sequence
      a = open_parens
      a << @open_quote if @open_quote
      a
    end

    def open_delimiter
      open_sequence.last
    end
    
  end
  
  def initialize
    @lexer = SqlLex.new()
  end

  def parse(input)
    stmts = []
    s = @lexer.stream(input)
    stmt = nil
    loop do
      token, value, raw = s.shift
      break if token.nil? or :end == token
      if stmt.nil?
        stmt = Statement.new
      end
      stmt.tokens << token
      stmt.values << value
      stmt.raw += raw
      if :open == token
        stmt.open_quote = value
        break
      end
      if :semicolon == token
        stmt.semicolon_terminated = true
        stmts << stmt
        stmt = nil
      end
    end
    stmts << stmt if stmt
    stmts
  end
  
end
