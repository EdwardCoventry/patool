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
"""Archive commands for the unace program."""

def extract_ace (archive, compression, cmd, **kwargs):
    """Extract a ACE archive."""
    cmdlist = [cmd, 'x']
    if not kwargs['verbose']:
        cmdlist.append('-c-')
    outdir = kwargs['outdir']
    if not outdir.endswith('/'):
        outdir += '/'
    cmdlist.extend([archive, outdir])
    return cmdlist

def list_ace (archive, compression, cmd, **kwargs):
    """List a ACE archive."""
    cmdlist = [cmd]
    if kwargs['verbose']:
        cmdlist.append('v')
    else:
        cmdlist.append('l')
        cmdlist.append('-c-')
    cmdlist.append(archive)
    return cmdlist

def test_ace (archive, compression, cmd, **kwargs):
    """Test a ACE archive."""
    cmdlist = [cmd, 't']
    if not kwargs['verbose']:
        cmdlist.append('-c-')
    cmdlist.append(archive)
    return cmdlist
