#!/usr/bin/perl -w
package C;

use strict;
use Mozilla::OpenLDAP::API qw(LDAP_PORT LDAPS_PORT LDAP_SCOPE_SUBTREE);
use vars qw ($LDAPServerHost $LDAPServerPort $SearchFilter $TestBase);

$LDAPServerHost = 'localhost';
$LDAPServerPort = LDAP_PORT;
$TestBase       = 'ou=People, o=test';
$SearchFilter   = '(uid=*)';

1;
