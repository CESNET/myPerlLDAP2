#!/usr/bin/perl -w
package C;

use strict;
use perlOpenLDAP::API qw(LDAP_PORT LDAPS_PORT LDAP_SCOPE_SUBTREE);
use vars qw ($LDAPServerHost $LDAPServerPort $SearchFilter $TestBase $BindDN $BindPasswd $TestRDN);

$LDAPServerHost = 'tady.ten.cz';
$LDAPServerPort = LDAP_PORT;
$TestBase       = 'ou=People,o=test';
$SearchFilter   = '(uid=*)';
$TestRDN        = 'uid=test';
$BindDN         = 'cn=Manager, o=test';
$BindPasswd     = 'test_secret';

1;
