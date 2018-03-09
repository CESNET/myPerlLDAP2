#!/usr/bin/perl -w

BEGIN { $| = 1; print "1..6\n";}
#END {print "not ok 1\n" unless $SOK;}

use lib qw(/home/honza/proj/myPerlLDAP);
use strict;
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
my $conn = new myPerlLDAP::conn({"host"   => $C::LDAPServerHost,
				 "port"   => $C::LDAPServerPortS,
				 "certdb" => 1,
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
$entry->addValues('cn', 'Test Testovič', 'lang-cs');
$entry->addValues('givenName', 'Test');
$entry->addValues('givenName', 'Test2');
$entry->addValues('givenName', 'Test3');
$entry->addValues('givenName', 'Test4');
$entry->addValues('givenName', 'Test5');
$entry->addValues('mail', 'test@testing.universe');
$entry->addValues('homedirectory', '/home/test111');
$entry->addValues('uidnumber', '30001');
$entry->addValues('gidnumber', '30001');
$entry->addValues('userpassword', 'heslo12345X');

if ($entry->isModified) {
  print "ok 3\n";
} else {
  print "not ok 3\n";
};


# - 4 -----------------------------------------------------------------------
$conn->add($entry) or $SOK = 0;
printf "not ok 4 (%s)\n", $conn->errorMessage unless $SOK;
print "ok 4\n" if $SOK;

# - 5 -----------------------------------------------------------------------
if ($entry->isModified) {
  print "not ok 5\n";
} else {
  print "ok 5\n";
};

# - 6 -----------------------------------------------------------------------
$SOK = 1;
$conn->close or $SOK = 0;
print "not ok 6\n" unless $SOK;
print "ok 6\n" if $SOK;
