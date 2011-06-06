
# psql-odbc #

## Overview ##

`psql-odbc` is a SQL prompt for an ODBC database.  The client
works like `psql`, the command line utility distributed with
PostgreSQL.

## Installation ##

* install ruby (including rubygems)
* sudo gem install ruby-odbc
* install the odbc driver for your database

## To Do ##

* (DONE) use optparse and process arguments like psql does
* (DONE) format the output of a select like psql does
* (DONE) don't exit upon SQL errors
* (DONE) not using the prompt provided pw?
* (IMPOSSIBLE) align sql error message so caret ^ points at error in statement
* cleanup meta_command regexes
* modify psql so that unit tests can send input and capture output
* parse sql to identify multiple statements, run each separately
* parse sql to identify whether statement is a select.  display appropriate msg for non-selects
* lift 100 ROWS LIMITATION (use first 100 for size, then let longer fields overflow)
* make parser aware of commas and the *
* implement the meta-commands
  * (DONE) \d table
  * (DONE) \d (list all tables)
  * (DONE) \q
  * (DONE) \c
  * (DONE) \? help
  * (DONE) \o (file or pipe)
  * \i
  * \!
  * (DONE) \cd
  * \t (show only rows)
  * \f VALUE (show/set field separator)
  * \a aligned/unaligned output toggle
* query buffer commands
  * \e [file]         (edit query buffer)
  * \g [file] or pipe (run query buffer)
  * \r clear query buffer
  * \w <file> write query buffer
* tab completion? table names, column names
* pager
* usage
* test under mac
* startup file .psql-odbc-rc
* unit test for command line
* test under ruby 1.9
* test under cygwin
* run under windows (with no readline?)
* abstract out netezza specific code
* add a nzsql symlink
* make psql-odbc aware of the name by which it was invoked
* test against other odbc databases