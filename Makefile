# DealerDesk build and test entry point (spec 001-build-and-tests).
#
#   make                 build ./dealerdesk
#   make test            build, then run unit and end-to-end tests
#   make unit | e2e      run one half of the suite
#   make test-mutation   check that a wrong pricing constant makes the suite fail
#   make test-compat     check that the a2ba708 binary still reads files written now
#   make golden          regenerate e2e goldens (only for new or re-baselined scenarios)
#   make clean           remove build outputs
#
# Same sources and libraries as `gcc -o dealerdesk *.c -lm`; only warning flags added.

CC     ?= cc
CFLAGS ?= -Wall
LDLIBS  = -lm

SRCS = main.c calc.c dbfile.c screen.c
HDRS = calc.h dbfile.h globals.h screen.h

UNIT = tests/unit/test_calc

.PHONY: all test unit e2e golden test-mutation test-compat clean

all: dealerdesk

dealerdesk: $(SRCS) $(HDRS)
	$(CC) $(CFLAGS) -o $@ $(SRCS) $(LDLIBS)

$(UNIT): tests/unit/test_calc.c calc.c calc.h
	$(CC) $(CFLAGS) -I. -o $@ tests/unit/test_calc.c calc.c $(LDLIBS)

unit: $(UNIT)
	./$(UNIT)

e2e: dealerdesk
	sh tests/e2e/run.sh ./dealerdesk

test: all
	@status=0; \
	$(MAKE) --no-print-directory unit || status=1; \
	$(MAKE) --no-print-directory e2e || status=1; \
	if [ $$status -eq 0 ]; then echo "make test: ALL PASSED"; else echo "make test: FAILED"; fi; \
	exit $$status

golden: dealerdesk
	sh tests/e2e/run.sh --update ./dealerdesk

test-compat:
	sh tests/compat.sh

test-mutation:
	sh tests/mutation.sh

clean:
	rm -f dealerdesk *.o $(UNIT)

# Tests for the release scripts (spec 003). Needs zip for the packaging case.
.PHONY: test-release
test-release:
	sh tests/release/test_release.sh
