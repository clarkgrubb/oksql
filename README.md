
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
* format the output of a select like psql does
* (DONE) don't exit upon SQL errors
* align sql error message so caret ^ points at error in statement
* implement the meta-commands
* test under mac
* startup file .psql-odbc-rc
* parse sql to identify strings (multiple statments?
  whether statment is a select?)
* unit tests?
* test under ruby 1.9
* test under cygwin
* abstract out netezza specific code
* add a nzsql symlink
* make psql-odbc aware of the name by which it was invoked
