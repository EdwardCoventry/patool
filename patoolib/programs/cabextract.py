# -*- coding: utf-8 -*-
# Copyright (C) 2010-2013 Bastian Kleineidam
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
"""Archive commands for the cabextract program."""

def extract_cab (archive, compression, cmd, **kwargs):
    """Extract a CAB archive."""
    cmdlist = [cmd, '-d', kwargs['outdir']]
    if kwargs['verbosity'] > 0:
        cmdlist.append('-v')
    cmdlist.append(archive)
    return cmdlist

def list_cab (archive, compression, cmd, **kwargs):
    """List a CAB archive."""
    cmdlist = [cmd, '-l']
    if kwargs['verbosity'] > 0:
        cmdlist.append('-v')
    cmdlist.append(archive)
    return cmdlist

def test_cab (archive, compression, cmd, **kwargs):
    """Test a CAB archive."""
    return [cmd, '-t', archive]
