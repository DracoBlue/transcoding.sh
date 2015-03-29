help:

	@echo "Possible targets:"
	@echo "  test - build all test suites"
	@exit 0

ensure-test-fixtures:

	@if [ ! -d tests/fixtures ]; then mkdir tests/fixtures; fi
	@if [ ! -f tests/fixtures/big_buck_bunny.mp4 ]; then cd tests/fixtures/ && wget --quiet http://www.quirksmode.org/html5/videos/big_buck_bunny.mp4 && cd -; fi
	@if [ ! -d tests/results ]; then mkdir tests/results; fi

test:

	@make ensure-test-fixtures
	@tests/run_tests_unix

.PHONY: test help

# vim: ts=4:sw=4:noexpandtab!: