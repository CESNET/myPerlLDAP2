#!/usr/bin/perl -w

package myPerlLDAP::Utils;

use strict;
use vars qw($VERSION @ISA %EXPORT_TAGS);

use Mozilla::OpenLDAP::API qw(LDAP_SCOPE_SUBTREE LDAP_SCOPE_BASE LDAP_SCOPE_ONELEVEL ldap_explode_dn);

@ISA = qw(Exporter);
$VERSION = "0.0.1";
%EXPORT_TAGS = (
		all => [qw(normalizeDN
			   str2Scope)]
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

# Konec pohadky ;-)
1;
