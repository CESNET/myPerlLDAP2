#!/usr/bin/perl -w

BEGIN { $| = 1; print "1..6\n";}
#END {print "not ok 1\n" unless $SOK;}

use lib qw(/home/honza/proj/myPerlLDAP);
use strict;
use Mozilla::OpenLDAP::API qw(LDAP_PORT LDAPS_PORT LDAP_SCOPE_SUBTREE);
use myPerlLDAP::Conn;
use myPerlLDAP::Entry;
use myPerlLDAP::Attribute;
use t::C;
use vars qw($SOK);
$SOK = 1;
print "ok 1\n" if $SOK;

# Don't warm about missing attribute classes
$myPerlLDAP::Attribute::_D=0;

# - 2 -----------------------------------------------------------------------
$SOK = 1;
my $conn = new myPerlLDAP::Conn({"host"   => $C::LDAPServerHost,
				 "port"   => $C::LDAPServerPort,
				 "bind"   => "$C::BindDN",
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
$entry->attr('userPassword')->set('password') if $SOK;
print "not ok 4\n" unless $SOK;
print "ok 4\n" if $SOK;

# - 5 -----------------------------------------------------------------------
$SOK = 1;
$conn->update($entry) or $SOK = 0;
print "not ok 5\n" unless $SOK;
print "ok 5\n" if $SOK;

# - 6 -----------------------------------------------------------------------
$SOK = 1;
$conn->close or $SOK = 0;
print "not ok 6\n" unless $SOK;
print "ok 6\n" if $SOK;
