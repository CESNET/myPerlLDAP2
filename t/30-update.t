#!/usr/bin/perl -w
#$Id$

# #############################################################################
# myPerlLDAP - object oriented interface for work with LDAP
# Copyright (C) 2001,02 by Jan Tomasek
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Library General Public License for more details.
#
# You should have received a copy of the GNU Library General Public
# License along with this library; if not, write to the Free
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
# #############################################################################

BEGIN { $| = 1; print "1..12\n";}
#END {print "not ok 1\n" unless $SOK;}

use lib qw(/home/honza/proj/myPerlLDAP);
use strict;
use perlOpenLDAP::API qw(LDAP_PORT LDAPS_PORT LDAP_SCOPE_SUBTREE);
use myPerlLDAP::conn;
use myPerlLDAP::entry;
use myPerlLDAP::attribute;
use Data::Dumper;
use t::C;
use vars qw($SOK);
$SOK = 1;
print "ok 1\n" if $SOK;

# Don't warm about missing attribute classes
$myPerlLDAP::attribute::_D=0;

# - 2 -----------------------------------------------------------------------
$SOK = 1;
my $conn = new myPerlLDAP::conn({"host"   => $C::LDAPServerHost,
				 "port"   => $C::LDAPServerPort,
				 "bind"   => $C::BindDN,
				 "pswd"   => $C::BindPasswd}) or $SOK = 0;
print "not ok 2\n" unless $SOK;
print "ok 2\n" if $SOK;

# - 3 -----------------------------------------------------------------------
$SOK = 1;
my $res = $conn->search($C::TestBase, LDAP_SCOPE_SUBTREE,
			"($C::TestRDN)") or $SOK = 0;
print "not ok 3\n" unless $SOK;
print "ok 3\n" if $SOK;

# - 4 -----------------------------------------------------------------------
$SOK = 1;
my $entry = $res->nextEntry or $SOK = 0;
print "not ok 4\n" unless $SOK;
print "ok 4\n" if $SOK;

# - 5 -----------------------------------------------------------------------
if ($entry->isModified) {
  print "not ok 5\n";
} else {
  print "ok 5\n";
};

# - 6 -----------------------------------------------------------------------
$entry->addValues('description', 'Popiska');
$entry->addValues('loginShell', '/bin/false');
#$entry->removeAttr('givenName');
$entry->removeAttr('mail');
$entry->addValues('givenName', 'Trotl');
$entry->addValues('givenName', 'Trotlik');
$entry->addValues('cn', 'BFU');

if ($entry->isModified) {
  print "ok 6\n";
} else {
  print "not ok 6\n";
};

# - 7 -----------------------------------------------------------------------
$SOK = 1;
$conn->update($entry) or $SOK = 0;
print "not ok 7\n" unless $SOK;
print "ok 7\n" if $SOK;

# - 8 -----------------------------------------------------------------------
if ($entry->isModified) {
  print "not ok 8\n";
} else {
  print "ok 8\n";
};

# - 9 -----------------------------------------------------------------------
$entry->addValues('cn', 'BFU2');
$entry->removeValues('givenName', 'Test2');
$entry->addValues('givenName', 'Test-Q');
$entry->addValues('givenName', 'Test-Z');
if ($entry->isModified) {
  print "ok 9\n";
} else {
  print "not ok 9\n";
};

# - 10 ----------------------------------------------------------------------
$SOK = 1;
$conn->update($entry) or $SOK = 0;
print "not ok 10\n" unless $SOK;
print "ok 10\n" if $SOK;

# - 11 ----------------------------------------------------------------------
if ($entry->isModified) {
  print "not ok 11\n";
} else {
  print "ok 11\n";
};

# - 12 ----------------------------------------------------------------------
$SOK = 1;
$entry->removeValues('description', 'Popiska');
$conn->update($entry) or $SOK = 0;
print "not ok 12\n" unless $SOK;
print "ok 12\n" if $SOK;

# - 13 ----------------------------------------------------------------------
$SOK = 1;
$entry->attr('loginShell')->setValues(undef);
$conn->update($entry) or $SOK = 0;
print "not ok 13\n" unless $SOK;
print "ok 13\n" if $SOK;


# - 14 ----------------------------------------------------------------------
$SOK = 1;
$conn->close or $SOK = 0;
print "not ok 14\n" unless $SOK;
print "ok 14\n" if $SOK;
