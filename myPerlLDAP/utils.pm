#!/usr/bin/perl -w

package myPerlLDAP::utils;

use strict;
use vars qw($VERSION @ISA %EXPORT_TAGS);

use perlOpenLDAP::API qw(LDAP_SCOPE_SUBTREE LDAP_SCOPE_BASE LDAP_SCOPE_ONELEVEL ldap_explode_dn);

@ISA = qw(Exporter);
$VERSION = "0.0.1";
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
