#!/usr/bin/perl -w

BEGIN { $| = 1; print "1..4\n";}
#END {print "not ok 1\n" unless $SOK;}

use lib qw(/home/honza/proj/myPerlLDAP);
use strict;
use Mozilla::OpenLDAP::API qw(LDAP_PORT LDAPS_PORT LDAP_SCOPE_BASE);
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
$entry->addAsValues('objectclass', ['top', 'person', 'inetOrgPerson', 'posixAccount']);
$entry->addAsValues('uid', 'test');
$entry->addAsValues('sn', 'Testovic');
$entry->addAsValues('cn', 'Test Testovic');
$entry->addAsValues('givenName', 'Test');
$entry->addAsValues('mail', 'test@testing.universe');
$entry->addAsValues('homedirectory', '/home/test111');
$entry->addAsValues('uidnumber', '30001');
$entry->addAsValues('gidnumber', '30001');
$entry->addAsValues('userpassword', '{SSHA}kGoZtcaIHFPNXt0Rk+3c2InF7sCeqRhB');

$conn->add($entry) or $SOK = 0;
print "not ok 3\n" unless $SOK;
print "ok 3\n" if $SOK;

# - 4 -----------------------------------------------------------------------
$SOK = 1;
$conn->close or $SOK = 0;
print "not ok 4\n" unless $SOK;
print "ok 4\n" if $SOK;
