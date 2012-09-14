TEST_DSN=NZSQL

test:
	for test_file in *test.rb; do \
	PSQL_ODBC_TEST_DSN=$(TEST_DSN) ruby $$test_file; \
	done
