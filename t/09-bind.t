#!/usr/bin/perl -w
#$Id$

BEGIN { $| = 1; print "1..7\n";}
#END {print "not ok 1\n" unless $SOK;}

use strict;
#use perlOpenLDAP::API qw(LDAP_PORT LDAPS_PORT LDAP_SCOPE_SUBTREE);
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
$SOK = 1;
my $conn = construct myPerlLDAP::conn({"host"   => $C::LDAPServerHost,
				       "port"   => $C::LDAPServerPort})
  or $SOK = 0;
print "not ok 2\n" unless $SOK;
print "ok 2\n" if $SOK;

# - 3 -----------------------------------------------------------------------
$SOK = 1;
$conn->init or $SOK = 0;
print "not ok 3\n" unless $SOK;
print "ok 3\n" if $SOK;

# - 4 -----------------------------------------------------------------------
$SOK = 1;
$conn = construct myPerlLDAP::conn({"host"   => $C::LDAPServerHost,
				    "port"   => $C::LDAPServerPortS,
				    "certdb" => 1,
				    "bind"   => $C::BindDN,
				    "pswd"   => $C::BindPasswd.'XXX'})
  or $SOK = 0;
print "not ok 4\n" unless $SOK;
print "ok 4\n" if $SOK;

# - 5 -----------------------------------------------------------------------
$SOK = 1;
$conn->init or $SOK = 0;
print "not ok 5\n" if $SOK;
print "ok 5\n" unless $SOK;

# - 6 -----------------------------------------------------------------------
$SOK = 1;
$conn = construct myPerlLDAP::conn({"host"   => $C::LDAPServerHost,
				    "port"   => $C::LDAPServerPortS,
				    "certdb" => 1,
				    "bind"   => $C::BindDN,
				    "pswd"   => $C::BindPasswd})
  or $SOK = 0;
print "not ok 6\n" unless $SOK;
print "ok 6\n" if $SOK;

# - 7 -----------------------------------------------------------------------
$SOK = 1;
$conn->init or $SOK = 0;
print "not ok 7\n" unless $SOK;
print "ok 7\n" if $SOK;

