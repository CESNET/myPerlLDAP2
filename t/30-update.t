#!/usr/bin/perl -w

BEGIN { $| = 1; print "1..19\n";}

use lib qw(../myPerlLDAP2);
use strict;
use warnings FATAL => 'all';
use myPerlLDAP::conn;
use myPerlLDAP::entry;
use myPerlLDAP::attribute;
use myPerlLDAP::utils qw(:all);
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
				 "port"   => $C::LDAPServerPortS,
				 "certdb" => 1,
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
my $expected_entry = join('!', sort split("\n", 'dn: uid=test,ou=People,o=test
sn: Testovic
gidnumber: 30001
objectclass: top
objectclass: person
objectclass: inetOrgPerson
objectclass: posixAccount
objectclass: organizationalPerson
uidnumber: 30001
mail: test@testing.universe
cn: Test Testovic
cn;lang-cs:: VGVzdCBUZXN0b3ZpxI0=
givenname: Test
givenname: Test2
givenname: Test3
givenname: Test4
givenname: Test5
uid: test
homedirectory: /home/test111'));

my $found_entry = join('!', sort grep {$_ !~ /^userpassword/i} @{$entry->LDIF});

$SOK = ($found_entry eq $expected_entry);
print "not ok 5\n" unless $SOK;
print "ok 5\n" if $SOK;

# - 6 -----------------------------------------------------------------------
if ($entry->isModified) {
  print "not ok 6\n";
} else {
  print "ok 6\n";
};

# - 7 -----------------------------------------------------------------------
$entry->addValues('description', 'Popiska');
$entry->addValues('loginShell', '/bin/false');
$entry->removeAttr('mail');
$entry->addValues('givenName', 'Trotl');
$entry->addValues('givenName', 'Trotlik');
$entry->addValues('cn', 'BFU');
$entry->removeValues('givenName', 'Test2');

if ($entry->isModified) {
  print "ok 7\n";
} else {
  print "not ok 7\n";
};

# - 8 -----------------------------------------------------------------------
$SOK = 1;
$conn->update($entry) or $SOK = 0;
print "not ok 8\n" unless $SOK;
print "ok 8\n" if $SOK;

# - 9 -----------------------------------------------------------------------
my $modified_entry = join('!', sort grep {$_ !~ /^userpassword/i} @{$entry->LDIF});
$expected_entry = join('!', sort split("\n", 'dn: uid=test,ou=People,o=test
sn: Testovic
gidnumber: 30001
objectclass: top
objectclass: person
objectclass: inetOrgPerson
objectclass: posixAccount
objectclass: organizationalPerson
uidnumber: 30001
cn: Test Testovic
cn;lang-cs:: VGVzdCBUZXN0b3ZpxI0=
givenname: Test
givenname: Test3
givenname: Test4
givenname: Test5
uid: test
homedirectory: /home/test111
description: Popiska
loginshell: /bin/false
givenname: Trotl
givenname: Trotlik
cn: BFU'));

$SOK = ($modified_entry eq $expected_entry);
print "not ok 9\n" unless $SOK;
print "ok 9\n" if $SOK;

# - 10 ----------------------------------------------------------------------
$entry = $conn->read($entry->dn);
$found_entry = join('!', sort grep {$_ !~ /^userpassword/i} @{$entry->LDIF});

$SOK = ($found_entry eq $expected_entry);
print "not ok 10\n" unless $SOK;
print "ok 10\n" if $SOK;

# - 11 ----------------------------------------------------------------------
if ($entry->isModified) {
    print "not ok 11\n";
} else {
    print "ok 11\n";
};

# - 12 ----------------------------------------------------------------------
$entry->addValues('cn', 'BFU2');
$entry->removeValues('givenName', 'Test2');
$entry->addValues('givenName', 'Test-Q');
$entry->addValues('givenName', 'Test-Z');
if ($entry->isModified) {
    print "ok 12\n";
} else {
    print "not ok 12\n";
};

# - 13 ---------------------------------------------------------------------
$SOK = 1;
$conn->update($entry) or $SOK = 0;
print "not ok 13\n" unless $SOK;
print "ok 13\n" if $SOK;

# - 14 ----------------------------------------------------------------------
if ($entry->isModified) {
    print "not ok 14\n";
} else {
    print "ok 14\n";
};

# - 15 ----------------------------------------------------------------------
$SOK = 1;
$entry->removeValues('description', 'Popiska');
$conn->update($entry) or $SOK = 0;
print "not ok 15\n" unless $SOK;
print "ok 15\n" if $SOK;

# - 16 ----------------------------------------------------------------------
$SOK = 1;
$entry->attr('loginShell')->setValues(undef); # TODO 2020.04.20 tohle nefunguje a test to nedetekuje!
$entry->removeValues('givenName', 'Test-Q');
$conn->update($entry) or $SOK = 0;
print "not ok 16\n" unless $SOK;
print "ok 16\n" if $SOK;

# - 17 ----------------------------------------------------------------------
$SOK = 1;
$entry->setValues('description', 'Nova Popiska');
$conn->update($entry) or $SOK = 0;
print "not ok 17\n" unless $SOK;
print "ok 17\n" if $SOK;

# - 18 ----------------------------------------------------------------------
$SOK = 1;
$entry->setValues('description', '');
$conn->update($entry) or $SOK = 0;
print "not ok 18\n" unless $SOK;
print "ok 18\n" if $SOK;

# - 19 ----------------------------------------------------------------------
$SOK = 1;
$conn->close or $SOK = 0;
print "not ok 19\n" unless $SOK;
print "ok 19\n" if $SOK;
