
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
* (DONE) parse sql to identify multiple statements, run each separately
* (DONE) make parser aware of commas and the *
* (DONE) ability to mix sql and meta-commands, separated by semicolons
* (DONE) must be whitespace between meta-command and semicolon
* cleanup meta_command regexes
* modify psql so that unit tests can send input and capture output
* parse sql to identify whether statement is a select.  display appropriate msg for non-selects
* lift 100 ROWS LIMITATION (use first 100 for size, then let longer fields overflow)
* CRUD output:
 * INSERT 0 1 (explanation of first number: If count is exactly one, and the target table has OIDs, then oid is the OID assigned to the inserted row. Otherwise oid is zero.)
 * UPDATE 2
 * DELETE 2
* CREATE output:
  * CREATE TABLE
  * DROP TABLE
  * ALTER TABLE
  * TRUNCATE TABLE
* GRANT output
  * GRANT
  * REVOKE
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

* extensions
 * \buffer <name>  # header: column names and types
 * list buffers (with dates, command that created)
 * transforms
  * \awk \ruby \perl \sed
 * persistence
  * \csv \org \sqllite \temp \file
 * graphing data
* emacs extension version?
* package as gem
* usage
* test under mac
* startup file .psql-odbc-rc
* test under ruby 1.9
* test under cygwin
* run under windows (with no readline?)
* abstract out netezza specific code
* add a nzsql symlink
* make psql-odbc aware of the name by which it was invoked
* test against other odbc databases
* direct support for psql, mysql, sql server, sqllite, (oracle?)