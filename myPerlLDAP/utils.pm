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

package myPerlLDAP::utils;

use strict;
use vars qw(@ISA %EXPORT_TAGS);

use perlOpenLDAP::API qw(LDAP_SCOPE_SUBTREE LDAP_SCOPE_BASE LDAP_SCOPE_ONELEVEL ldap_explode_dn);

@ISA = qw(Exporter);
%EXPORT_TAGS = (
		all => [qw(normalizeDN
			   str2Scope
			   quote4XML
			   quote4HTTP)]
		);
# Add Everything in %EXPORT_TAGS to @EXPORT_OK
Exporter::export_ok_tags('all');

#############################################################################
# Convert a "human" readable string to an LDAP scope value
#
# Without any change copied from Mozilla::perLDAP::Utils
#
sub str2Scope {
  my ($str) = $_[0];

  return $str if ($str =~ /^[0-9]+$/);

  if ($str =~ /^sub/i) {
    return LDAP_SCOPE_SUBTREE;
  } elsif ($str =~ /^base/i) {
    return LDAP_SCOPE_BASE;
  } elsif ($str =~ /^one/i) {
    return LDAP_SCOPE_ONELEVEL;
  };

  # Default...
  return LDAP_SCOPE_SUBTREE;
};

#############################################################################
# Normalize the DN string (first argument), and return the new, normalized,
# string (DN). This is useful to make sure that two syntactically
# identical DNs compare (eq) as the same string.
#
# Without any change copied from Mozilla::perLDAP::Utils
#
sub normalizeDN {
  my ($dn) = @_;
  my (@vals);

  return "" unless (defined($dn) && ($dn ne ""));

  @vals = ldap_explode_dn(lc $dn, 0);

  return join(",", @vals);
};

#############################################################################
# Escape all for XML danger characters
#
sub quote4XML {
  my $bla = shift;

  $bla =~ s/&/&amp;/g;
  $bla =~ s/\^/&\#94;/g;
  $bla =~ s/\(/&\#40;/g;
  $bla =~ s/\)/&\#41;/g;

  return $bla;
};

#############################################################################
# Escape all for HTTP danger characters
#
sub quote4HTTP {
  my $bla = shift;

  $bla =~ s/ /%20/g;

  return $bla;
};

# Konec pohadky ;-)
1;
