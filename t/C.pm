#!/usr/bin/perl -w

package C;

use strict;
#TODO use perlOpenLDAP::API qw(LDAP_PORT LDAPS_PORT LDAP_SCOPE_SUBTREE);
use vars qw ($LDAPServerHost $LDAPServerPort $LDAPServerPortS $SearchFilter $TestBase $BindDN $BindPasswd $TestRDN @attrs);

#$LDAPServerHost = 'tady.ten.cz';

$LDAPServerPort  =  389; # TODO LDAP_PORT;
$LDAPServerPortS =  636; # TODO LDAP_PORT;
$SearchFilter   = '(objectClass=*)';
$TestRDN        = 'uid=test';

@attrs          = ('objectClass',
		   'uid',
		   'userPassword',
		   'cn',
		   'tailDegree',
		   'headDegree');

#$LDAPServerHost = 'cml.cesnet.cz';
#$TestBase       = 'ou=People,dc=cesnet,o=test';
#$BindDN         = 'uid=test,ou=People,o=test';
#$BindPasswd     = 'test123456';

$LDAPServerHost = 'cml.cesnet.cz';
$TestBase       = 'ou=People,o=test';
$BindDN         = 'uid=user,ou=People,o=test';
$BindPasswd     = 'test123456';

#$LDAPServerHost = 'localhost';
#$TestBase       = 'ou=People,o=test';
#$BindDN         = 'cn=Manager, o=test';
#$BindPasswd     = 'test_secret';

1;
