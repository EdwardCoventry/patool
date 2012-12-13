# This Makefile is only used by developers.
PYVER:=2.7
PYTHON:=python$(PYVER)
APPNAME:=patool
VERSION:=$(shell $(PYTHON) setup.py --version)
ARCHIVE:=$(APPNAME)-$(VERSION).tar.gz
ARCHIVE_RPM:=$(APPNAME)-$(VERSION)-1.x86_64.rpm
ARCHIVE_WIN32:=$(APPNAME)-$(VERSION).exe
PY_FILES_DIRS := patool setup.py patoolib tests
PY2APPOPTS ?=
ifeq ($(shell uname),Darwin)
  CHMODMINUSMINUS:=
else
  CHMODMINUSMINUS:=--
endif
# Pytest options:
# --resultlog: write test results in file
# -s: do not capture stdout/stderr (some tests fail otherwise)
PYTESTOPTS:=--resultlog=testresults.txt -s
# which test modules to run
TESTS ?= tests/
# set test options
TESTOPTS=

all:


chmod:
	-chmod -R a+rX,u+w,go-w $(CHMODMINUSMINUS) *
	find . -type d -exec chmod 755 {} \;

dist:
	git archive --format=tar --prefix=$(APPNAME)-$(VERSION)/ HEAD | gzip -9 > ../$(ARCHIVE)
#	cd .. && zip -r - patool-git -x "**/.git/**" > $(HOME)/temp/share/patool-devel.zip

sign:
	[ -f ../$(ARCHIVE).sha1 ] || sha1sum ../$(ARCHIVE) > ../$(ARCHIVE).sha1
	[ -f ../$(ARCHIVE).asc ] || gpg --detach-sign --armor ../$(ARCHIVE)
	[ -f ../$(ARCHIVE_WIN32).sha1 ] || sha1sum ../$(ARCHIVE_WIN32) > ../$(ARCHIVE_WIN32).sha1
	[ -f ../$(ARCHIVE_WIN32).asc ] || gpg --detach-sign --armor ../$(ARCHIVE_WIN32)
	[ -f dist/$(ARCHIVE_RPM).sha1 ] || sha1sum dist/$(ARCHIVE_RPM) > dist/$(ARCHIVE_RPM).sha1
	[ -f dist/$(ARCHIVE_RPM).asc ] || gpg --detach-sign --armor dist/$(ARCHIVE_RPM)

upload:	doc/README.md sign
	rsync -avP -e ssh doc/README.md ../$(ARCHIVE)* ../$(ARCHIVE_WIN32)* dist/$(ARCHIVE_RPM)* calvin,patool@frs.sourceforge.net:/home/frs/project/p/pa/patool/$(VERSION)/

doc/README.md: doc/README-Download.md.tmpl doc/changelog.txt
# copying readme for sourceforge downloads
	sed -e 's/{APPNAME}/$(APPNAME)/g' -e 's/{VERSION}/$(VERSION)/g' $< > $@
# append changelog
	awk '/released/ {c++}; c==2 {exit}; {print "    " $$0}' doc/changelog.txt >> $@


release: clean releasecheck dist upload
	git tag upstream/$(VERSION)
	@echo "Register at Python Package Index..."
	$(PYTHON) setup.py register
	freecode-submit < patool.freecode


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
app: clean chmod
	$(PYTHON) setup.py py2app $(PY2APPOPTS)

rpm:
	$(PYTHON) setup.py bdist_rpm

# The check programs used here are mostly local scripts on my private system.
# So for other developers there is no need to execute this target.
check:
	[ ! -d .svn ] || check-nosvneolstyle -v
	check-copyright
	check-pofiles -v
	py-tabdaddy
	py-unittest2-compat tests/

pyflakes:
	pyflakes $(PY_FILES_DIRS)

count:
	@sloccount patool patoolib | grep "Total Physical Source Lines of Code"

clean:
	find . -name \*.pyc -delete
	find . -name \*.pyo -delete
	rm -rf build dist doc/README.md

test:
	$(PYTHON) -m pytest $(PYTESTOPTS) $(TESTOPTS) $(TESTS)

doc/patool.txt: doc/patool.1
	cols=`stty size | cut -d" " -f2`; stty cols 72; man -l doc/patool.1 | perl -pe 's/.\cH//g' > doc/patool.txt; stty cols $$cols

deb:
	git-buildpackage --git-upstream-branch=master --git-debian-branch=debian  --git-ignore-new

update-copyright:
	update-copyright --holder="Bastian Kleineidam"

changelog:
	sftrack_changelog patool calvin@users.sourceforge.net doc/changelog.txt $(DRYRUN)

.PHONY: changelog update-copyright deb test clean count pyflakes check rpm app
.PHONY: releasecheck release upload sign dist chmod all
