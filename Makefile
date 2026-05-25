# Makefile for Hello Chapel + BigSort projects
#
# BigSort is the main program: a high-performance parallel sorter in Chapel.
# The original hello world is kept for minimal examples.

# Prefer chpl in PATH; fall back to common Homebrew or custom locations
CHPL ?= $(shell which chpl 2>/dev/null || echo /usr/local/bin/chpl)

# Common flags. Add -O for optimized builds, --fast for maximum performance.
CHPL_FLAGS ?= -O

# Use bundled GMP (helps with some Homebrew installs)
export CHPL_GMP ?= bundled

.PHONY: all build run hello bigsort clean test

all: bigsort

# --- BigSort (recommended target) ---
bigs: bigsort

bigsort: bigsort.chpl
	$(CHPL) $(CHPL_FLAGS) bigsort.chpl -o bigsort

run-bigs: bigsort
	./bigsort --n=1000000 --verify --compare

# Quick sanity check with a small dataset
test: bigsort
	./bigsort --n=100000 --quiet --verify

# --- Original Hello World (minimal example) ---
hello: hello.chpl
	$(CHPL) $(CHPL_FLAGS) hello.chpl -o hello

run: hello
	./hello

build: bigsort hello

clean:
	rm -f hello hello_real bigsort bigsort_real

# Multi-locale (distributed) build example - requires GASNet/Chapel multi-locale setup
build-dist:
	$(CHPL) --comm=gasnet --comm-substrate=udp $(CHPL_FLAGS) bigsort.chpl -o bigsort

run-dist: build-dist
	./bigsort --n=5000000 --verify
