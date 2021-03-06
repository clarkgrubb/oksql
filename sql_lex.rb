# coding: utf-8

class SqlLex

  # These are not precise
  KEYWORD_OR_VARIABLE_REGEX = '[a-zA-Z_][a-zA-Z_0-9]*'
  OPERATOR_REGEX = '[+\-*\/%\|,]+'
  INTEGER_REGEX = '-?[0-9]+'
  FLOAT_REGEX = '-?[0-9]+\.[0-9]*|-?[0-9]*\.[0-9]+'
  UNKNOWN_REGEX = '\S+'
  META_COMMAND_REGEX = '\\\\.*?\s;|\\\\.*$'

  # TODO: support double quoted identifiers

  def initialize()
  end

  def lex_comment(input)
    case input
    when /\A(\s*)(--.*\n?)/
      return :comment, $2, $1 + $2, $'
    when /\A(\s*')/
      raw_prefix, raw_rest = $1, $'
      token, value, raw_rest, rest = lex_string(raw_rest)
      rest = "'" + rest if :open == token
      return token, value, raw_prefix + raw_rest, rest
    when /\A(\s*")/
      raw_prefix, raw_rest = $1, $'
      token, value, raw_rest, rest = lex_quoted_variable(raw_rest)
      rest = '"' + rest if :open == token
      return token, value, raw_prefix + raw_rest, rest
    when /\A(\s*)(#{META_COMMAND_REGEX})/
      postmatch = $'
      return :meta_command, $2, $1 + $2, $'
    when /\A(\s*)(#{KEYWORD_OR_VARIABLE_REGEX})/
      return :keyword_or_variable, $2, $1 + $2, $'
    when /\A(\s*)(#{FLOAT_REGEX})/
      return :float, $2, $1 + $2, $'
    when /\A(\s*)(#{INTEGER_REGEX})/
      return :integer, $2, $1 + $2, $'
    when /\A(\s*)(\.)/
      return :identifier_separator, $2, $1 + $2, $'
    when /\A(\s*)\(/
      postmatch = $'
      return :open_paren, '(', $1 + '(', postmatch
    when /\A(\s*)\)/
      postmatch = $'
      return :close_paren, ')', $1 + ')', postmatch
    when /\A(\s*);/
      postmatch = $'
      return :semicolon, ';', $1 + ';', postmatch
    when /\A(\s*)(#{OPERATOR_REGEX})/
      postmatch = $'
      return :operator, $2, $1 + $2, postmatch
    when /\A(\s*)(#{UNKNOWN_REGEX})/
      postmatch = $'
      return :unknown, $2, $1 + $2, postmatch
    when /\A(\s*)\Z/
      return :end, nil, $1, nil
    else
      return :error, nil, nil, input
    end
  end

  def lex_quoted_variable(input)
    lex_delimited_token(input, '"', :quoted_variable)
  end

  def lex_string(input)
    lex_delimited_token(input, "'", :string)
  end

  def lex_delimited_token(input, delimiter, token)
    value = ''
    raw = ''
    loop do
      if /\A([^#{delimiter}]*)#{delimiter}/.match(input)
        value += $1
        raw += $1 + delimiter
        input = $'
        if input[0..0] == delimiter
          value += delimiter
          raw += delimiter
          input = input[1..-1]
        else
          return token, value, raw, input
        end
      else
        rest = raw + input
        return :open, delimiter, rest, rest
      end
    end
  end

  def lex(input)
    loop do
      token, value, raw, rest = lex_comment(input)
      if :comment == token
        raise "infinite loop on input: #{input}" if input == rest
        input = rest
      else
        return token, value, raw, rest
      end
    end
  end

  def stream(input)
    rest = input
    a = []
    loop do
      token, value, raw, new_rest = lex(rest)
      a << [token, value, raw]
      break if [:end, :open, :error].include?(token)
      if new_rest == rest
        raise "software errror: infinite loop on input: #{rest}"
      end
      rest = new_rest
    end
    a
  end

end
