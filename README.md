
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

* abstract out netezza specific code
* add a nzsql symlink
* make psql-odbc aware of the name by which it was invoked
* use argparse and process arguments like psql does
* format the output of a select line psql does
* implement the meta-commands
* parse sql to identify strings (multiple statments?
  whether statment is a select?)