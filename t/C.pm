#!/usr/bin/perl -w
#$Id$

# #############################################################################
# myPerlLDAP - object oriented interface for work with LDAP
# Copyright (C) 2001,02 by Jan Tomasek
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Library General Public License for more details.
#
# You should have received a copy of the GNU Library General Public
# License along with this library; if not, write to the Free
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
# #############################################################################

package C;

use strict;
use perlOpenLDAP::API qw(LDAP_PORT LDAPS_PORT LDAP_SCOPE_SUBTREE);
use vars qw ($LDAPServerHost $LDAPServerPort $SearchFilter $TestBase $BindDN $BindPasswd $TestRDN @attrs);

#$LDAPServerHost = 'tady.ten.cz';

$LDAPServerPort = LDAP_PORT;
$SearchFilter   = '(uid=*)';
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
$TestBase       = 'ou=People,dc=cesnet,o=test';
$BindDN         = 'uid=testmich,ou=People,dc=cesnet,o=test';
$BindPasswd     = 'test123456';

$LDAPServerHost = 'localhost';
$TestBase       = 'ou=People,o=test';
$BindDN         = 'cn=Manager, o=test';
$BindPasswd     = 'test_secret';

1;
