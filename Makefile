.PHONY: all install

PREFIX?=/usr/local

all: cb

install:
	cp cb $(PREFIX)/bin/
