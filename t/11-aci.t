#!/usr/bin/perl -w

BEGIN { $| = 1; print "1..14\n";}
#END {print "not ok 1\n" unless $SOK;}

use strict;
#use perlOpenLDAP::API 1.5 qw(/.+/);
use myPerlLDAP::conn;
use myPerlLDAP::entry;
use myPerlLDAP::aci;
use myPerlLDAP::attribute;
use myPerlLDAP::utils qw(:all);
use t::C;
use Data::Dumper;
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
my $aci = $conn->readACI($C::TestBase,
			 #atributy ktery nas zajimaji
			 @C::attrs) or $SOK = 0;

print "not ok 3\n" unless $SOK;
print "ok 3\n" if $SOK;

# - 4 -----------------------------------------------------------------------
$SOK = 1;
$SOK = 0 unless $aci->e('read');

print "not ok 4\n" unless $SOK;
print "ok 4\n" if $SOK;

# - 5 -----------------------------------------------------------------------
$SOK = 1;
$SOK = 0 if $aci->e('add');

print "not ok 5\n" unless $SOK;
print "ok 5\n" if $SOK;

# - 6 -----------------------------------------------------------------------
$SOK = 1;
$SOK = 0 unless $aci->a('objectClass', 'read');

print "not ok 6\n" unless $SOK;
print "ok 6\n" if $SOK;

# - 7 -----------------------------------------------------------------------
$SOK = 1;
$SOK = 0 if $aci->a('objectClass', 'write');

print "not ok 7\n" unless $SOK;
print "ok 7\n" if $SOK;

# - 8 -----------------------------------------------------------------------
#$SOK = 1;
#$SOK = 0 unless $conn->initACICTRL(@C::attrs);

#print "not ok 8\n" unless $SOK;
print "ok 8\n";# if $SOK;

# - 9 -----------------------------------------------------------------------
$SOK = 1;
my $res = $conn->search($C::TestBase, LDAP_SCOPE_BASE,
			'(objectClass=*)', 0, @C::attrs) or $SOK = 0;

print "not ok 9\n" unless $SOK;
print "ok 9\n" if $SOK;

# - 10 ----------------------------------------------------------------------
$SOK = 1;
my $entry = $res->nextEntry or $SOK = 0;

print "not ok 10\n" unless $SOK;
print "ok 10\n" if $SOK;

# - 11 ----------------------------------------------------------------------
$SOK = 1;
$SOK = 0 unless $entry->aci->e('read');

print "not ok 11\n" unless $SOK;
print "ok 11\n" if $SOK;

# - 12 ----------------------------------------------------------------------
$SOK = 1;
$SOK = 0 if $entry->aci->e('write');

print "not ok 12\n" unless $SOK;
print "ok 12\n" if $SOK;

# - 13 ----------------------------------------------------------------------
$SOK = 1;
$SOK = 0 unless $entry->aci->a('objectClass', 'read');

print "not ok 13\n" unless $SOK;
print "ok 13\n" if $SOK;

# - 14 ----------------------------------------------------------------------
$SOK = 1;
$SOK = 0 if $entry->aci->a('objectClass', 'write');

print "not ok 14\n" unless $SOK;
print "ok 14\n" if $SOK;



#warn $entry->LDIFString;


__END__
