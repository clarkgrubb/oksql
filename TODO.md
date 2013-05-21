* query buffer commands
  * \e \[file\]         (edit query buffer)
  * \g \[file\] or pipe (run query buffer)
  * \r clear query buffer
  * \w \<file\> write query buffer
* tab completion? table names, column names
* modify oksql so that unit tests can send input and capture output
* cleanup meta_command regexes
* cleanup signature of execute_sql
* test under mac
* double quoted identifiers

* extensions
 * \buffer <name>  # header: column names and types
 * list buffers (with dates, command that created)
 * transforms
  * \awk \ruby \perl \sed
 * persistence
  * \csv \org \sqllite \temp \file
 * graphing data
* spaces in filenames for \i and \o?
* usage
* test under ruby 1.9
* test under cygwin
* run under windows (with no readline?)
* abstract out netezza specific code
* test against other odbc databases
* direct support for sql server