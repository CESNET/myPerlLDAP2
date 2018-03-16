#!/usr/bin/perl -w

BEGIN { $| = 1; print "1..6\n";}
#END {print "not ok 1\n" unless $SOK;}

use lib qw(../myPerlLDAP2);
use strict;
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
				 "port"   => $C::LDAPServerPort}) or $SOK = 0;
print "not ok 2\n" unless $SOK;
print "ok 2\n" if $SOK;

# - 3 -----------------------------------------------------------------------
$SOK = 1;
my $res = $conn->search($C::TestBase, LDAP_SCOPE_SUBTREE,
			$C::SearchFilter) or $SOK = 0;
print "not ok 3\n" unless $SOK;
print "ok 3\n" if $SOK;

my $ldCount = $res->count;

# - 4 -----------------------------------------------------------------------
$SOK = 1;
$SOK = 0 unless ($res->cacheLocaly);
print "not ok 4\n" unless $SOK;
print "ok 4\n" if $SOK;

# - 5 -----------------------------------------------------------------------
$SOK = 1;
$SOK = 0 unless ($ldCount == $res->count);
print "not ok 5\n" unless $SOK;
print "ok 5\n" if $SOK;

# - 6 -----------------------------------------------------------------------
$SOK = 1;
my $flag = 0;
my @remove;
while (my $entry=$res->nextEntry) {
  if ($flag==0) {
    $flag++;
    push @remove, $entry->dn;
  } else {
    $flag=0;
  };
};
$res->removeLocaly(@remove);
$SOK = 0 unless (($ldCount-@remove) == $res->count);
print "not ok 6\n" unless $SOK;
print "ok 6\n" if $SOK;
