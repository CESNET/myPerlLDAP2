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

# #############################################################################
# This module contains some code pieces from Mozilla::OpenLDAP::Conn
# (extracted from Mozilla-OpenLDAP-API-1.4), please look at coments before
# definition of each function for info about it's origin. The original code
# was introduced by this:
#    The Original Code is PerLDAP. The Initial Developer of the Original
#    Code is Netscape Communications Corp. and Clayton Donley. Portions
#    created by Netscape are Copyright (C) Netscape Communications Corp.,
#    portions created by Clayton Donley are Copyright (C) Clayton Donley.
#    All Rights Reserved.
# #############################################################################

package myPerlLDAP::conn;

use strict;

# TODO: Dont' import all ... mod_perl eff :(
use perlOpenLDAP::API 1.4 qw(/.+/);
use myPerlLDAP::abstract;
use myPerlLDAP::utils qw(str2Scope normalizeDN);
use myPerlLDAP::entry;
use myPerlLDAP::searchResult;

use vars qw($VERSION @ISA %fields);

@ISA = ("myPerlLDAP::abstract");

$VERSION = "1.51";

%fields = (
	   debug => 1,
	   host => undef,
	   port => LDAP_PORT,
	   bindDN => undef,
	   bindPasswd => undef,
	   certDB => undef,
	   ld => undef,
	   ldRes => undef,
	   dn => undef,
	  );

#############################################################################
# Creator, create and initialize a new LDAP object ("connection"). We support
# either providing all parameters as a hash array, or as individual
# arguments.
#
# Without any changes copied from perLDAP-1.4
#
# TODO: For SSL use an betther flag than stupid certdb ... OpenLDAP client
# isn't now able to work with certs I think.

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $self = bless $class->SUPER::new(@_), $class;

  foreach my $element (keys %fields) {
    $self->{_permitted_fields}->{$element} = $fields{$element};
  };
  @{$self}{keys %fields} = values %fields;

  if (ref $_[$[] eq "HASH") {
    my ($hash);

    $hash = $_[$[];
    $self->host($hash->{"host"}) if defined($hash->{"host"});
    $self->port($hash->{"port"}) if defined($hash->{"port"});
    $self->bindDN($hash->{"bind"}) if defined($hash->{"bind"});
    $self->bindPasswd($hash->{"pswd"}) if defined($hash->{"pswd"});
    $self->certDB($hash->{"certdb"}) if defined($hash->{"certdb"});
  } else {
    my ($host, $port, $binddn, $bindpasswd, $certdb, $authmeth) = @_;

    $self->host($host);
    $self->port($port);
    $self->bindDN($binddn);
    $self->bindPasswd($bindpasswd);
    $self->certDB($certdb);
  };

  $self->bindDN("") unless defined($self->bindDN);
  $self->bindPasswd("") unless defined($self->bindPasswd);

  if (!defined($self->port) || ($self->port eq "")) {
    $self->port((($self->certDB ne "") ? LDAPS_PORT : LDAP_PORT));
  }

  return unless $self->init();
  return $self;
}; # new -------------------------------------------------------------------

#############################################################################
# Destructor, makes sure we close any open LDAP connections.
#
# Without any changes copied from perLDAP-1.4
#
sub DESTROY {
  my ($self) = shift;

  return unless defined($self->ld);

  $self->close();
}; # DESTROY ----------------------------------------------------------------

#############################################################################
# Initialize a normal connection. This seems silly, why not just merge
# this back into the creator method (new)...
#
# Folowing code is based on perlLDAP-1.4 was modified by Milan (I think)
# for OpenLDAP, and some other minor changes were done by me ... it will
# not be merged back to constructor I like this way ;-)
sub init {
  my ($self) = shift;
  my ($ret, $ld);

  if (defined($self->certDB) && ($self->certDB ne "")) {
    $ret = ldapssl_client_init($self->certDB, 0);
    return if ($ret < 0);

    $ld = ldapssl_init($self->host, $self->port, 1);
  } else {
    $ld = ldap_init($self->host, $self->port);
  };
  return unless $ld;

  $self->ld($ld);
  $ret = ldap_simple_bind_s($ld, $self->bindDN, $self->bindPasswd);

  return (($ret == LDAP_SUCCESS) ? 1 : undef);
} # init --------------------------------------------------------------------

#############################################################################
# Create a new, empty, Entry object.
#
# Personaly I don't se any reason for this function, but I'm will leave it
# here for users migrating from Mozilla:perLDAP or Mozilla:OpenLDAP
#
sub newEntry {

  return new myPerlLDAP::entry;
} # newEntry ----------------------------------------------------------------

#############################################################################
# Checks if a string is a properly formed LDAP URL.
#
# Without any changes copied from perLDAP-1.4
#
sub isURL {
  my ($self, $url) = @_;

  return ldap_is_ldap_url($url);
} # isURL -------------------------------------------------------------------

#############################################################################
# Return the Error code from the last LDAP api function call. The last two
# optional arguments are pointers to strings, and will be set to the
# match string and extra error string if appropriate.
#
# Based on code of function getErrorCode from perLDAP-1.4
#
sub error {
  my ($self, $match, $msg) = @_;
  my ($ret);

  return LDAP_SUCCESS unless defined($self->ld);
  return ldap_get_lderrno($self->ld, $match, $msg);
}; # getErrorCode -----------------------------------------------------------

#############################################################################
# Return the Error string from the last LDAP api function call.
#
# Without any change copied from perLDAP-1.4
#
sub errorMessage {
  my ($self) = shift;
  my ($err);

  return LDAP_SUCCESS unless defined($self->ld);
  $err = ldap_get_lderrno($self->ld, undef, undef);

  return ldap_err2string($err);
} # getErrorString ----------------------------------------------------------

#############################################################################
# Print the last error code...
#
# Based on code from printError from perLDAP-1.4
#
sub printErrorMessage {
  my ($self, $str) = @_;

  return unless defined($self->ld);

  $str = "LDAP error:" unless defined($str);
  print "$str ", $self->errorMessage(), "\n";
} # printError --------------------------------------------------------------

#############################################################################
# Normal LDAP search. Note that this will actually perform LDAP URL searches
# if the filter string looks like a proper URL.
#
# Based on code from perLDAP-1.4 (they don't have any SerachResults class)
#
sub search {
  my ($self, $basedn, $scope, $filter, $attrsonly, @attrs) = @_;
  my ($resv, $entry);
  my ($res) = \$resv;

  $scope = str2Scope($scope);
  $filter = "(objectclass=*)" if ($filter =~ /^ALL$/i);

  if (defined($self->ldRes)) {
    ldap_msgfree($self->ldRes);
    $self->ldRes(undef);
    # undef $self->{"ldres"};
  };

  if (ldap_is_ldap_url($filter)) {
    if (! ldap_url_search_s($self->ld, $filter, $attrsonly, $res)) {
      my $sRes = new myPerlLDAP::searchResults($self->ld, $res);
      return $sRes;
    };
  } else {
    if (! ldap_search_s($self->ld, $basedn, $scope, $filter,
			defined(\@attrs) ? \@attrs : 0,
			defined($attrsonly) ? $attrsonly : 0,
			defined($res) ? $res : 0)) {
      my $sRes = new myPerlLDAP::searchResult($self->ld, $res);
      $sRes->owner($self);
      return $sRes;
    };
  };

  return $entry;
} # search ------------------------------------------------------------------

#############################################################################
# Read one entry identified by it's DN, list of required attrs is
# also supported.
#
sub read {
  my ($self, $dn, @attrs) = @_;
  my $resv;
  my $res = \$resv;

  if (@attrs and (scalar(@attrs)==1)) {
    @attrs = @{$attrs[0]} if (ref($attrs[0]) eq 'ARRAY');
  };

  if (!ldap_search_s($self->ld, $dn, LDAP_SCOPE_BASE, '(objectclass=*)',
		     defined(\@attrs) ? \@attrs : 0,
		     0,
		     defined($res) ? $res : 0)) {
    my $sRes = new myPerlLDAP::searchResult($self->ld, $res);
    if ($sRes) {
      my $entry = $sRes->nextEntry;
      return $entry;
    };
  };

  return undef;
}; # read -------------------------------------------------------------------

#############################################################################
# URL search, optimized for LDAP URL searches.
#
# Without any change copied from perLDAP-1.4
#
sub searchURL {
  my ($self, $url, $attrsonly) = @_;
  my ($resv, $entry);
  my ($res) = \$resv;

  if (defined($self->ldRes)) {
    ldap_msgfree($self->ldRes);
    $self->ldRes(undef);
  };

  if (!ldap_url_search_s($self->ld, $url,
			 defined($attrsonly) ? $attrsonly : 0,
			 defined($res) ? $res : 0)) {
    $self->ldRes = $res;
    $self->{ldfe} = 1;
    $entry = $self->nextEntry();
  };

  return $entry;
}; # searchURL -------------------------------------------------------------

#############################################################################
# Browse an LDAP entry, very much like the regular search, except we set
# some defaults (like scope=BASE, filter=(objectclass=*) and so on). Note
# that this method does not support the attributesOnly flag.
#
# Based on perlLDAP-1.4 code (I little reduced code)
#
sub browse {
  my ($self, $basedn, @attrs) = @_;

  return  $self->search($basedn, LDAP_SCOPE_BASE, "(objectclass=*)",
			0, @attrs);
}; # browse -----------------------------------------------------------------

#############################################################################
# Compare an attribute value against a DN in the server (without having to
# do a search first).
#
# Without any change copied from perLDAP-1.4
#
sub compare {
  my ($self, $dn, $attr, $value) = @_;

  return ldap_compare_s($self->ld, $dn, $attr, $value) ==
    LDAP_COMPARE_TRUE;
}; # compare ----------------------------------------------------------------

#############################################################################
# Close the connection to the LDAP server.
#
# With minor change copied from perLDAP-1.4
#
sub close {
  my $self = shift;
  my $ret = LDAP_SUCCESS; # Originaly was here that assignment $ret = 1 ...
                          # it never can't work; Actualy this is useles ...

  ldap_unbind_s($self->ld) if defined($self->ld);
  if (defined($self->ldRes)) {
    ldap_msgfree($self->ldRes);
    $self->ldres(undef);
  };
  $self->ld(undef);

  return (($ret == LDAP_SUCCESS) ? 1 : undef);
}; # close ------------------------------------------------------------------

#############################################################################
# Delete an object. An Entry ...
#
# With minor changes copied from perLDAP-1.4
#
# TODO: This will not work with clases based on myLDAP::entry or will??
sub delete {
  my $self = shift;
  my $id = shift;
  my $dn = $id;

  if (ref($id) eq 'myLDAP::entry') {
    $dn = $id->dn;
  } else {
    $self->dn($dn) unless (defined($dn) && ($dn ne ""));
  };

  $dn = normalizeDN($dn);
  my $ret = ldap_delete_s($self->ld, $dn) if ($dn ne "");

  return (($ret == LDAP_SUCCESS) ? 1 : undef);
}; # delete -----------------------------------------------------------------

#############################################################################
# Add an object. This fuction expect as argument myPerlLDAP::entry,
# it will not accept HASH like original function from perlLDAP!
#
# Based on perlLDAP, heavy modified for my new Entry ... most of code was
# deleted, functionality is now in Entry::makeAddRecord
#
sub add {
  my ($self, $entry) = @_;

  return unless $entry;

  my $rec = $entry->makeAddRecord;
  my $ret = ldap_add_s($self->ld, $entry->dn, $rec);

  if ($ret == LDAP_SUCCESS) {
    $entry->clearModifiedFlags;
    return 1;
  } else {
    return undef;
  };
}; # add --------------------------------------------------------------------

#############################################################################
# Modify the RDN, and update the entry accordingly. Note that the last
# two arguments (DN and "delete") are optional. The last (optional) argument
# is a flag, which if set to TRUE (the default), will cause the corresponding
# attribute value to be removed from the entry.
#
# Without any change copied from perLDAP-1.4
#
sub modifyRDN {
  my ($self, $rdn, $dn, $del) = ($_[$[], $_[$[ + 1], $_[$[ + 2], $_[$[ + 3]);
  my (@vals);
  my ($ret) = 1;

  $del = 1 unless (defined($del) && ($del ne ""));
  $self->dn($dn) unless (defined($dn) && ($dn ne ""));

  @vals = ldap_explode_dn($dn, 0);
  if (lc($vals[$[]) ne lc($rdn)) {
    $ret = ldap_modrdn2_s($self->ld, $dn, $rdn, $del);
    if ($ret == LDAP_SUCCESS) {
      shift(@vals);
      unshift(@vals, ($rdn));
      $self->dn(join(@vals));
    };
  };

  return (($ret == LDAP_SUCCESS) ? 1 : 0);
}; # modifyRDN --------------------------------------------------------------

#############################################################################
# Update an object.
#
# Inspired by perlLDAP-1.4 code - most of code was deleted, functionality
# is now in Entry::makeModificationRecord. Each book about OOP says:
#
#    "Nerver let user or other class using your class touch it's
#     internal structures."
#
sub update {
  my ($self, $entry) = @_;

  my $rec = $entry->makeModificationRecord;
  my $ret = ldap_modify_s($self->ld, $entry->dn, $rec);

  if ($ret == LDAP_SUCCESS) {
    $entry->clearModifiedFlags;
    return 1;
  } else {
    return undef
  };
}; # update -----------------------------------------------------------------

#############################################################################
# Set the rebind procedure. We also provide a neat default rebind procedure,
# which takes three arguments (DN, password, and the auth method). This is an
# extension to the LDAP SDK, which I think should be there. It was also
# needed to get this to work on Win/NT...
#
# Without any change copied from perLDAP-1.4 ... I've no idea what is this
#
sub setRebindProc {
  my ($self, $proc) = @_;

  # Should we try to reinitialize the connection?
  die "No LDAP connection" unless defined($self->ld);

  ldap_set_rebind_proc($self->ld, $proc);
}; # setRebindProc ----------------------------------------------------------

sub setDefaultRebindProc {
  my ($self, $dn, $pswd, $auth) = @_;

  $auth = LDAP_AUTH_SIMPLE unless defined($auth);
  die "No LDAP connection"
    unless defined($self->ld);

  ldap_set_default_rebind_proc($self->ld, $dn, $pswd, $auth);
} # setDefaultRebindProc ----------------------------------------------------

#############################################################################
# Do a simple authentication, so that we can rebind as another user.
#
# Without any change copied from perLDAP-1.4
#
sub simpleAuth {
  my ($self, $dn, $pswd) = @_;
  my ($ret);

  $ret = ldap_simple_bind_s($self->ld, $dn, $pswd);

  return (($ret == LDAP_SUCCESS) ? 1 : 0);
}; # simpleAuth -------------------------------------------------------------


#############################################################################
# Mandatory TRUE return value.
#
1;
__END__

=head1 NAME

myPerLDAP::Conn - LDAP server connection object

=head1 SYNOPSIS

  use strict;
  use Mozilla::OpenLDAP::API qw(LDAP_PORT LDAPS_PORT LDAP_SCOPE_SUBTREE);
  use myPerlLDAP::Conn;

  my $LDAPServerHost = "localhost";
  my $LDAPServerPort = LDAP_PORT;

  my $conn = new myPerlLDAP::Conn({"host"   => $LDAPServerHost,
				   "port"   => $LDAPServerPort})
    or die "Can't connect to $LDAPServerHost:$LDAPServerPort";

  my @attr = ('cn', 'sn', 'givenname');
  my $res = $conn->search('ou=People,o=test', LDAP_SCOPE_SUBTREE,
	  		  '(uid=*)', 0, @attr)
    or do {
      $conn->printError();
      die "Can't search"
    };


  my $entry = $res->nextEntry;
  while ($entry) {
    print $entry->LDIFString;
    print "\n";

    $entry = $res->nextEntry;
  };

=head1 SEE ALSO

L<myPerlLDAP::searchResult>, L<myPerlLDAP::entry>, L<myPerlLDAP::attribute>

=cut
