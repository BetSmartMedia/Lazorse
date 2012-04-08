.PHONY : test

PATH := ./node_modules/.bin/:$(PATH)
LIBS = $(subst src,lib,$(subst coffee,js,$(wildcard ./src/*.coffee)))
HEAD = $(shell git describe --contains --all HEAD)
REPORTER ?= dot

all : lazorse.js $(LIBS)

lib/%.js : src/%.coffee
	@mkdir -p lib
	@coffee -pbc $< > $@

test : all
	@mocha --compilers coffee:coffee-script --reporter $(REPORTER)

%.js : %.coffee
	@coffee -pbc $< > $@

clean :
	@rm *.js lib/*.js || true

pages :
	$(MAKE) -C doc html

release : test pages
	git checkout gh-pages
	cp -R doc/.build/html/ .
	git commit -a -m v$(npm_package_version)
	git checkout $(HEAD)
