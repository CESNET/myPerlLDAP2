#!/usr/bin/perl -w

BEGIN { $| = 1; print "1..15\n";}

use strict;
use vars qw($SOK);

use myPerlLDAP::abstract;
use myPerlLDAP::attribute;
use myPerlLDAP::entry;
use myPerlLDAP::utils;
use t::C;

$myPerlLDAP::attribute::fields{debug}=0;
$myPerlLDAP::entry::fields{debug}=0;

$SOK = 1;
print "ok 1\n" if $SOK;

my $entry = new myPerlLDAP::entry;
$entry->dn("$C::TestRDN,$C::TestBase");

# Test adding by addValues
$SOK = 1;
$entry->addValues('objectClass', ['top', 'person', 'inetOrgPerson', 'posixAccount']) or $SOK=0;
$entry->addValues('UID', 'test') or $SOK=0;
$entry->addValues('sn', 'Testovic') or $SOK=0;
$entry->addValues('sn', 'Examplic', 'lang-en') or $SOK=0;
$entry->addValues('cn', 'Test Testovic') or $SOK=0;
$entry->addValues('givenName', 'Test') or $SOK=0;
$entry->addValues('mail', 'test1@testing.universe') or $SOK=0;
$entry->addValues('mail', 'test2@testing.universe') or $SOK=0;
$entry->addValues('mail', 'test3@testing.universe') or $SOK=0;
$entry->addValues('homeDirectory', '/home/test111') or $SOK=0;
$entry->addValues('UIDNumber', '30001') or $SOK=0;
$entry->addValues('GIDNumber', '30001') or $SOK=0;
$entry->addValues('userPassword', '{SSHA}kGoZtcaIHFPNXt0Rk+3c2InF7sCeqRhB') or $SOK=0;
print "not ok 2\n" unless $SOK;
print "ok 2\n" if $SOK;

# Test if correctly refuses adding same value again
$SOK = 0;
$entry->addValues('mail', 'test3@testing.universe') or $SOK=1;
print "not ok 3\n" unless $SOK;
print "ok 3\n" if $SOK;

my $mail = $entry->attr('mail');
my $givenName = $entry->attr('givenName');

# Test if correctly removes attrs from entry
$SOK = 1;
$entry->removeAttr('mail', 'giveNName')==2 or $SOK=0;
print "not ok 4\n" unless $SOK;
print "ok 4\n" if $SOK;

# Test if refuses removing non existing attr
$SOK = 0;
$entry->removeAttr('mail', 'xyz') or $SOK=1;
print "not ok 5\n" unless $SOK;
print "ok 5\n" if $SOK;

# Test adding outside prepared attrs
$SOK = 1;
$entry->addAttr($mail, $givenName)==2 or $SOK=0;
print "not ok 6\n" unless $SOK;
print "ok 6\n" if $SOK;

# Test adding to singleValue attr
$SOK = 0;
$entry->attr('uidNumber')->singleValue(1);
$entry->attr('uidNumber')->addValues(10000) or $SOK=1;
print "not ok 7\n" unless $SOK;
print "ok 7\n" if $SOK;

# Test adding to readOnly attr
$SOK = 0;
$entry->attr('mail')->readOnly(1);
$entry->attr('mail')->addValues('nobody@nowhere.com') or $SOK=1;
$entry->attr('mail')->readOnly(0);
print "not ok 8\n" unless $SOK;
print "ok 8\n" if $SOK;

# Test removing values
$SOK = 1;
$entry->attr('mail')->removeValues('test2@testing.universe') or $SOK=0;
print "not ok 9\n" unless $SOK;
print "ok 9\n" if $SOK;

# Test removing multiple and not existing values
$SOK = 1;
$entry->attr('mail')->removeValues(['test2@testing.universe',
				    'test3@testing.universe'])==1 or $SOK=0;
print "not ok 10\n" unless $SOK;
print "ok 10\n" if $SOK;

# Test removing values of not existing attribute
$SOK = 1;
$entry->removeValues('businessCategory', ['SLA1',
					  'BFU2'])==0 or $SOK=0;
print "not ok 11\n" unless $SOK;
print "ok 11\n" if $SOK;

# Test seting values of existing attribute
$SOK = 1;
$entry->setValues('mail', ['test1@cesnet.cz',
			   'test2@cesnet.cz'])==2 or $SOK=0;
print "not ok 12\n" unless $SOK;
print "ok 12\n" if $SOK;

# Test seting values of notexisting attribute
$SOK = 1;
$entry->setValues('businessCategory', ['SLA1',
				       'BFU2'])==2 or $SOK=0;
print "not ok 13\n" unless $SOK;
print "ok 13\n" if $SOK;

# Test matchValues
$SOK = 1;
@{$entry->matchValues('businessCategory', '^B')}==1 or $SOK=0;
print "not ok 14\n" unless $SOK;
print "ok 14\n" if $SOK;

$SOK = 0;
@{$entry->matchValues('business-Category', '^B')}==1 or $SOK=1;
print "not ok 15\n" unless $SOK;
print "ok 15\n" if $SOK;

#print $entry->XMLString;

