# SUMMARY

`oksql` is a SQL prompt for an ODBC database.  The client
works like `psql`, the command line utility distributed with
PostgreSQL.

# SETUP

Ruby and Rubygems should already be installed.  On Ubuntu run

    $ sudo make setup.ubuntu

On Mac OS X you can do the following if Homebrew is installed:

    $ make setup.brew

On either system this will install the necessary Ruby gems:

    $ sudo make setup

You can install `oksql` in /usr/local/bin by running

    $ sudo make install

# HOW TO RUN: NETEZZA

    $ oksql
