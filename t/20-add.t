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

BEGIN { $| = 1; print "1..4\n";}
#END {print "not ok 1\n" unless $SOK;}

use lib qw(/home/honza/proj/myPerlLDAP);
use strict;
use perlOpenLDAP::API qw(LDAP_PORT LDAPS_PORT LDAP_SCOPE_BASE);
use myPerlLDAP::conn;
use myPerlLDAP::entry;
use myPerlLDAP::attribute;
use t::C;
use vars qw($SOK);
$SOK = 1;
print "ok 1\n" if $SOK;

# Don't warm about missing attribute classes
$myPerlLDAP::attribute::_D=0;

# - 2 -----------------------------------------------------------------------
my $conn = new myPerlLDAP::conn({"host"   => $C::LDAPServerHost,
				 "port"   => $C::LDAPServerPort,
				 "bind"   => $C::BindDN,
				 "pswd"   => $C::BindPasswd}) or $SOK = 0;
print "not ok 2\n" unless $SOK;
print "ok 2\n" if $SOK;

# Make sure that entry isn't there ;-)
$conn->delete("$C::TestRDN,$C::TestBase");

# - 3 -----------------------------------------------------------------------
$SOK = 1;
my $entry = new myPerlLDAP::entry;
$entry->dn("$C::TestRDN,$C::TestBase");
$entry->addValues('objectclass', ['top', 'person', 'inetOrgPerson', 'posixAccount']);
$entry->addValues('uid', 'test');
$entry->addValues('sn', 'Testovic');
$entry->addValues('cn', 'Test Testovic');
$entry->addValues('givenName', 'Test');
$entry->addValues('mail', 'test@testing.universe');
$entry->addValues('homedirectory', '/home/test111');
$entry->addValues('uidnumber', '30001');
$entry->addValues('gidnumber', '30001');
$entry->addValues('userpassword', '{SSHA}kGoZtcaIHFPNXt0Rk+3c2InF7sCeqRhB');

$conn->add($entry) or $SOK = 0;
printf "not ok 3 (%s)\n", $conn->errorMessage unless $SOK;
print "ok 3\n" if $SOK;

# - 4 -----------------------------------------------------------------------
$SOK = 1;
$conn->close or $SOK = 0;
print "not ok 4\n" unless $SOK;
print "ok 4\n" if $SOK;
