#!/usr/bin/perl -w

BEGIN { $| = 1; print "1..4\n";}
#END {print "not ok 1\n" unless $SOK;}

use lib qw(../myPerlLDAP2);
use strict;
use myPerlLDAP::conn;
use myPerlLDAP::entry;
use myPerlLDAP::attribute;
use myPerlLDAP::utils qw(:all);
use t::C;
use vars qw($SOK);
$SOK = 1;
print "ok 1\n" if $SOK;

my $a=1;


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
my $res = $conn->search($C::TestBase, LDAP_SCOPE_ONE,
			$C::SearchFilter) or $SOK = 0;
print "not ok 3\n" unless $SOK;
print "ok 3\n" if $SOK;

$res->cacheLocaly;

# - 4 -----------------------------------------------------------------------
$SOK = 1;
my $c1 = 0;
my $cn1 = '';
while (my $entry = $res->nextEntry) {
    my $dump = join("\n", @{$entry->XML});
    my $a = $entry->getValues('cn')->[0].":".$entry->dn."!";
    $cn1 .= $a;
    #print ">>>>>> $a\n";
    $c1++;
};
$SOK = 0 unless $c1;

print "not ok 4\n" unless $SOK;
print "ok 4\n" if $SOK;

$res->sort('sn', 'givenName');

# - 5 -----------------------------------------------------------------------
$SOK = 1;
$res->reset;
my $c2 = 0;
my $cn2 = '';
while (my $entry = $res->nextEntry) {
    my $dump = join("\n", @{$entry->XML});
    my $a = $entry->getValues('cn')->[0].":".$entry->dn."!";
    $cn2 .= $a;
    #print ">>>>>> $a\n";
    
    $c2++;
};
$SOK = 0 unless $c2==$c1;

print "not ok 5\n" unless $SOK;
print "ok 5\n" if $SOK;

# - 6 -----------------------------------------------------------------------
$SOK=$cn1 ne $cn2;
print "not ok 6\n" unless $SOK;
print "ok 6\n" if $SOK;
