#!/usr/bin/perl -w

BEGIN { $| = 1; print "1..7\n";}
#END {print "not ok 1\n" unless $SOK;}

use lib qw(/home/honza/proj/myPerlLDAP);
use strict;
use myPerlLDAP::utils qw /:all/;
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
my $conn = new myPerlLDAP::conn({"host"   => $C::LDAPServerHost,
				 "port"   => $C::LDAPServerPort}) or $SOK = 0;
print "not ok 2\n" unless $SOK;
print "ok 2\n" if $SOK;

# - 3 -----------------------------------------------------------------------
$SOK = 1;
my $res = $conn->search($C::TestBase, LDAP_SCOPE_SUBTREE,
			$C::SearchFilter) or $SOK = 0;
print "not ok 3 (".$conn->errorMessage.")\n" unless $SOK;
print "ok 3\n" if $SOK;

# - 4 -----------------------------------------------------------------------
$SOK = 1;
my $entry = $res->nextEntry or $SOK = 0;
my $ldif = '';
my $c1 = 0;
my $dn = $entry->dn if $entry;
while ($entry) {
    $ldif .= $entry->LDIFString."\n";
    $entry = $res->nextEntry;
    $dn = $entry->dn if $entry;
    $c1++;
};
print "not ok 4\n" unless $SOK;
print "ok 4\n" if $SOK;


# - 5 -----------------------------------------------------------------------
$SOK = 1;
my $c2 = 0;
$ldif = '';
$res->reset;
$entry = $res->nextEntry or $SOK = 0;
while ($entry) {
    $ldif .= $entry->LDIFString."\n";
    $entry = $res->nextEntry;
    $c2++;
};
$SOK = 0 if ($c1 != $c2);
print "not ok ($c1, $c2) 5\n" unless $SOK;
print "ok 5\n" if $SOK;

# - 6 -----------------------------------------------------------------------
$SOK = 1;
if (defined($dn)) {
  $entry = $conn->read($dn);
  $SOK = 0 unless ($entry);
} else {
  $SOK = 0;
};
print "not ok 6\n" unless $SOK;
print "ok 6\n" if $SOK;

# - 7 ----------------------------------------------------------------------
$SOK = 1;
$conn->close or $SOK = 0;
print "not ok 7\n" unless $SOK;
print "ok 7\n" if $SOK;


#TODO jeste nejaky cteni s autentizovanym bindem?
