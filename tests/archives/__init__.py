# -*- coding: utf-8 -*-
# Copyright (C) 2010-2012 Bastian Kleineidam
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
import unittest
import os
import shutil
import patoolib
from .. import basedir, datadir

# All text files have '42' as content.
TextFileContent = '42'

class Content:
    """The test archives have one of several set of content files.
    The different content file sets have each a constant defined
    by this class.
    """

    # Recursive archives for extraction have a text file in a directory:
    # t/t.txt
    # Recursive archives for creation have two text files in directories:
    # foo dir/t.txt
    # foo dir/bar/t.txt
    Recursive = 'recursive'

    # Singlefile archives for extraction have a text file t.txt
    # Recursive archives for creation have a text file `foo .txt'
    Singlefile = 'singlefile'


class ArchiveTest (unittest.TestCase):
    """Helper class for archive tests, handling one commandline program."""

    # set program to use for archive handling in subclass
    program = None

    def archive_commands (self, filename, **kwargs):
        """Run archive commands list, test, extract and create.
        All keyword arguments are delegated to the create test function."""
        self.archive_list(filename)
        if not kwargs.get('skip_test'):
            self.archive_test(filename)
        if kwargs.get('singlefile'):
            check_default = Content.Singlefile
        else:
            check_default = Content.Recursive
        check = kwargs.get('check', check_default)
        if 'check' in kwargs:
            del kwargs['check']
        self.archive_extract(filename, check=check)
        if not kwargs.get('skip_create'):
            self.archive_create(filename, **kwargs)

    def archive_extract (self, filename, check=Content.Recursive):
        """Test archive extraction."""
        archive = os.path.join(datadir, filename)
        self.assertTrue(os.path.isabs(archive), "archive path is not absolute: %r" % archive)
        self._archive_extract(archive, check)
        # archive name relative to tmpdir
        relarchive = os.path.join("..", archive[len(basedir)+1:])
        self._archive_extract(relarchive, check, verbose=True)

    def _archive_extract (self, archive, check, verbose=False):
        # create a temporary directory for extraction
        tmpdir = patoolib.util.tmpdir(dir=basedir)
        try:
            olddir = os.getcwd()
        except OSError:
            olddir = None
        os.chdir(tmpdir)
        try:
            output = patoolib._handle_archive(archive, 'extract', program=self.program, verbose=verbose)
            if check:
                self.check_extracted_archive(archive, output, check)
        finally:
            if olddir:
                os.chdir(olddir)
            shutil.rmtree(tmpdir)

    def check_extracted_archive (self, archive, output, check):
        if check == Content.Recursive:
            # outdir is the 't' directory of the archive
            self.assertEqual(output, 't')
            self.check_directory(output, 't')
            txtfile = os.path.join(output, 't.txt')
            self.check_textfile(txtfile, 't.txt')
        elif check == Content.Singlefile:
            # a non-existing directory to ensure files do not exist in it
            ned = get_nonexisting_directory()
            expected_output = os.path.basename(patoolib.util.get_single_outfile(ned, archive))
            self.check_textfile(output, expected_output)

    def check_directory (self, dirname, expectedname):
        self.assertTrue(os.path.isdir(dirname), dirname)
        self.assertEqual(os.path.basename(dirname), expectedname)

    def check_textfile (self, filename, expectedname):
        self.assertTrue(os.path.isfile(filename), repr(filename))
        self.assertEqual(os.path.basename(filename), expectedname)
        self.assertEqual(get_filecontent(filename), TextFileContent)

    def archive_list (self, filename):
        """Test archive listing."""
        archive = os.path.join(datadir, filename)
        patoolib._handle_archive(archive, 'list', program=self.program)
        patoolib._handle_archive(archive, 'list', program=self.program, verbose=True)

    def archive_test (self, filename):
        """Test archive testing."""
        archive = os.path.join(datadir, filename)
        patoolib._handle_archive(archive, 'test', program=self.program)
        patoolib._handle_archive(archive, 'test', program=self.program, verbose=True)

    def archive_create (self, archive, srcfile=None, singlefile=False):
        """Test archive creation."""
        # determine filename which is added to the archive
        if srcfile is None:
            if singlefile:
                srcfile = 't.txt'
            else:
                srcfile = 't'
        os.chdir(datadir)
        # The format and compression arguments are needed for creating
        # archives with unusual file extensions.
        self._archive_create(archive, srcfile, program=self.program)
        # create again in verbose mode
        self._archive_create(archive, srcfile, program=self.program,
            verbose=True)

    def _archive_create (self, archive, srcfile, **kwargs):
        """Create archive from filename."""
        self.assertFalse(os.path.isabs(srcfile))
        self.assertTrue(os.path.exists(srcfile))
        # create a temporary directory for creation
        tmpdir = patoolib.util.tmpdir(dir=basedir)
        archive = os.path.join(tmpdir, archive)
        self.assertTrue(os.path.isabs(archive), "archive path is not absolute: %r" % archive)
        try:
            patoolib._handle_archive(archive, 'create', srcfile, **kwargs)
            self.assertTrue(os.path.isfile(archive))
            self.check_created_archive_with_test(archive)
            self.check_created_archive_with_diff(archive, srcfile)
        finally:
            shutil.rmtree(tmpdir)

    def check_created_archive_with_test(self, archive):
        command = 'test'
        program = self.program
        # special case for programs that cannot test what they create
        if self.program in ('compress', 'py_gzip'):
            program = 'gzip'
        elif self.program == 'py_bz2':
            program = 'bzip2'
        elif self.program == 'zip':
            program = 'unzip'
        elif self.program in ('rzip', 'shorten'):
            program = 'py_echo'
            command = 'list'
        elif self.program == 'lcab':
            program = 'cabextract'
        elif self.program == 'shar':
            return
        patoolib._handle_archive(archive, command, program=program)

    def check_created_archive_with_diff(self, archive, srcfile):
        """Extract created archive again and compare the contents."""
        # diff srcfile and output
        diff = patoolib.util.find_program("diff")
        if not diff:
            return
        program = self.program
        # special case for programs that cannot extract what they create
        if self.program == 'compress':
            program = 'gzip'
        elif self.program == 'zip':
            program = 'unzip'
        elif self.program == 'lcab':
            program = 'cabextract'
        elif self.program == 'shar':
            program = 'unshar'
        tmpdir = patoolib.util.tmpdir(dir=basedir)
        try:
            olddir = os.getcwd()
        except OSError:
            olddir = None
        os.chdir(tmpdir)
        try:
            output = patoolib._handle_archive(archive, 'extract', program=program)
            res = patoolib.util.run([diff, "-urN", srcfile, output])
            self.assertEqual(res, 0)
        finally:
            if olddir:
                os.chdir(olddir)
            shutil.rmtree(tmpdir)


def get_filecontent(filename):
    fo = open(filename)
    try:
        return fo.read()
    finally:
        fo.close()


def get_nonexisting_directory():
    d = os.path.join(os.getcwd(), "foo")
    while os.path.exists(d):
        d += 'a'
    return d
