#!/usr/bin/perl -w
#$Id$

BEGIN { $| = 1; print "1..11\n";}
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

# test prechodu z anonymiho na autentizovanyho binda
# - 8 -----------------------------------------------------------------------
# anonymni bind
$SOK = 1;
$conn = new myPerlLDAP::conn({"host"   => $C::LDAPServerHost,
			      "port"   => $C::LDAPServerPortS,
			      "certdb" => 1,
			     })
  or $SOK = 0;
print "not ok 8\n" unless $SOK;
print "ok 8\n" if $SOK;

# - 9 -----------------------------------------------------------------------
# nacist atribut co bychom nemeli anonymne cist
$SOK = 1;
my $entry = $conn->read($C::BindDN);
my $pwd = $entry->getValues('radiusPassword')->[0]
    or $SOK=0;
print "ok 9\n" unless $SOK;
print "not ok 9\n" if $SOK;

# - 10 ----------------------------------------------------------------------
# prepnout se na autentizovany bind
$SOK = 1;
$conn->simpleAuth($C::BindDN, $C::BindPasswd)
  or $SOK = 0;
print "not ok 10\n" unless $SOK;
print "ok 10\n" if $SOK;

# - 11 ----------------------------------------------------------------------
# nacist atribut co se da precist jen autentizovane 
$SOK = 1;
$entry = $conn->read($C::BindDN);
$pwd = $entry->getValues('radiusPassword')->[0] || undef;
$SOK=0 if ($pwd ne 'test123');
print "not ok 11\n" unless $SOK;
print "ok 11\n" if $SOK;
