SHELL := /bin/bash
.SHELLFLAGS :=  -o pipefail

.DELETE_ON_ERROR:
.SUFFIXES:

TEST_DSN := NZSQL
PWD := $(shell pwd)
INSTALL_DIR ?= /usr/local/bin

debug:
	echo $(PWD)

setup.ubuntu:
	apt-get install unixodbc-dev

setup.brew:
	brew install unixodbc

setup.ruby:
	gem install ruby-odbc highline

setup: setup.ruby

install:
	echo $$'exec $(PWD)/oksql.rb' > $(INSTALL_DIR)/oksql
	chmod 0755 $(INSTALL_DIR)/oksql 

test:
	find . -name '*_test.rb' | OKSQL_TEST_DSN=$(TEST_DSN) xargs -n 1 ruby
