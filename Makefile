# This Makefile is only used by developers.
PYVER:=2.7
PYTHON:=python$(PYVER)
APPNAME:=patool
VERSION:=$(shell $(PYTHON) setup.py --version)
ARCHIVE:=$(APPNAME)-$(VERSION).tar.gz
ARCHIVE_WIN32:=$(APPNAME)-$(VERSION).win32.exe
PY_FILES_DIRS := patool setup.py patoolib tests
PY2APPOPTS ?=
ifeq ($(shell uname),Darwin)
  NOSETESTS:=/usr/local/share/python/nosetests
  NUMPROCESSORS:=$(shell sysctl -a | grep machdep.cpu.core_count | cut -d " " -f 2)
  CHMODMINUSMINUS:=
else
  NOSETESTS:=$(shell which nosetests)
  NUMPROCESSORS:=$(shell grep -c processor /proc/cpuinfo)
  CHMODMINUSMINUS:=--
endif
+NOSETESTS:=$(shell which nosetests)
# Nose options:
# - do not show output of successful tests
# - use multiple processors
# - be verbose
# - only run test_* methods
NOSEOPTS:=--logging-clear-handlers --processes=$(NUMPROCESSORS) -v -m '^test_.*'
# which test modules to run
TESTS ?= tests/
# set test options, eg. to "--nologcapture"
TESTOPTS=

all:


.PHONY: chmod
chmod:
	-chmod -R a+rX,u+w,go-w $(CHMODMINUSMINUS) *
	find . -type d -exec chmod 755 {} \;

.PHONY: dist
dist:
	git archive --format=tar --prefix=$(APPNAME)-$(VERSION)/ HEAD | gzip -9 > ../$(ARCHIVE)
	[ -f ../$(ARCHIVE).sha1 ] || sha1sum ../$(ARCHIVE) > ../$(ARCHIVE).sha1
	[ -f ../$(ARCHIVE).asc ] || gpg --detach-sign --armor ../$(ARCHIVE)
	[ -f ../$(ARCHIVE_WIN32).sha1 ] || sha1sum ../$(ARCHIVE_WIN32) > ../$(ARCHIVE_WIN32).sha1
	[ -f ../$(ARCHIVE_WIN32).asc ] || gpg --detach-sign --armor ../$(ARCHIVE_WIN32)
#	cd .. && zip -r - patool-git -x "**/.git/**" > $(HOME)/temp/share/patool-devel.zip

.PHONY: upload
upload:	dist/README.md
	rsync -avP -e ssh ../$(ARCHIVE)* ../$(ARCHIVE_WIN32)* calvin,patool@frs.sourceforge.net:/home/frs/project/p/pa/patool/$(VERSION)/

dist/README.md: doc/README-Download.md.tmpl doc/changelog.txt
# copying readme for sourceforge downloads
	sed -e 's/{APPNAME}/$(APPNAME)/g' -e 's/{VERSION}/$(VERSION)/g' $< > $@
# append changelog
	awk '/released/ {c++}; c==2 {exit}; {print "    " $$0}' doc/changelog.txt >> $@


.PHONY: release
release: clean releasecheck dist upload
	git tag v$(VERSION)
	@echo "Register at Python Package Index..."
	$(PYTHON) setup.py register
	freecode-submit < patool.freecode


.PHONY: releasecheck
releasecheck: check test
	@if egrep -i "xx\.|xxxx|\.xx" doc/changelog.txt > /dev/null; then \
	  echo "Could not release: edit doc/changelog.txt release date"; false; \
	fi
	@if [ ! -f ../$(ARCHIVE_WIN32) ]; then \
	  echo "Missing WIN32 distribution archive at ../$(ARCHIVE_WIN32)"; \
	  false; \
	fi
	@if ! grep "Version: $(VERSION)" patool.freecode > /dev/null; then \
	  echo "Could not release: edit patool.freecode version"; false; \
	fi

# Build OSX installer
.PHONY: app
app: clean chmod
	$(PYTHON) setup.py py2app $(PY2APPOPTS)

# The check programs used here are mostly local scripts on my private system.
# So for other developers there is no need to execute this target.
.PHONY: check
check:
	[ ! -d .svn ] || check-nosvneolstyle -v
	check-copyright
	check-pofiles -v
	py-tabdaddy
	py-unittest2-compat tests/

.PHONY: pyflakes
pyflakes:
	pyflakes $(PY_FILES_DIRS)

.PHONY: count
count:
	@sloccount patool patoolib | grep "Total Physical Source Lines of Code"

.PHONY: clean
clean:
	find . -name \*.pyc -delete
	find . -name \*.pyo -delete
	rm -rf build dist

.PHONY: test
test:
	$(PYTHON) $(NOSETESTS) $(NOSEOPTS) $(TESTOPTS) $(TESTS)

doc/patool.txt: doc/patool.1
	cols=`stty size | cut -d" " -f2`; stty cols 72; man -l doc/patool.1 | perl -pe 's/.\cH//g' > doc/patool.txt; stty cols $$cols

.PHONY: deb
deb:
	git-buildpackage --git-export-dir=../build-area/ --git-upstream-branch=master --git-debian-branch=debian  --git-ignore-new

update-copyright:
	update-copyright --holder="Bastian Kleineidam"

.PHONY: changelog
changelog:
	sftrack_changelog patool calvin@users.sourceforge.net doc/changelog.txt $(DRYRUN)
