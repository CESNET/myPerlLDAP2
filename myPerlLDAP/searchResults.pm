#!/usr/bin/perl -w

package myPerlLDAP::searchResults;

use perlOpenLDAP::API 1.4 qw(ldap_first_entry ldap_next_entry ldap_msgfree ldap_get_dn ldap_first_attribute ldap_next_attribute ldap_get_values_len ldap_ber_free ldap_count_entries);
use strict;
use Carp;

use vars qw($VERSION $_D);

$VERSION = "0.2.2";

$_D = 1;

# TODO:
#   - firstNetry
#   - count      ... I acctualy don't need this, but they
#                    should be fine

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = {};

  $self->{_D} = $_D;

  if (($_D >= 10) || ($self->{_D} >= 10)) {
    carp("$class created");
  };

  bless($self, $class);
  return unless $self->init(@_);

  return $self;
};

sub init {
  my $self = shift;
  my $ld = shift;
  my $res = shift;

  if (defined($ld) and defined($res)) {
    $self->{ldres}=$res;
    $self->{ld}=$ld;
    $self->{ldfe}=1;

    return $self;
  } else {
    carp("$self->init requires ld and res args");
    return undef;
  };
};

#############################################################################
# Add new attribute to entry if necessary and add values to it. Only for
# internal use by myPerlLDAP::searchResults::nextEntry
#
sub addValues2Entry {
  my $self = shift;
  my $entry = shift;
  my $lcattr = shift;
  my $values = shift;

  $lcattr =~ /(^[^;]+)(;|)(.*?)$/;
  my $attrName = undef; $attrName = $1 if ($1 ne '');
  my $valueType = undef; $valueType = $3 if ($3 ne '');

  my $eattr = $entry->attr($attrName);
  if (defined($eattr)) {
    $eattr->add($values, $valueType);
  } else {
    $entry->addAsValues($attrName, $values, $valueType);
  };

  return $eattr;
};

#############################################################################
# Get an entry from the search, either the first entry, or the next entry,
# depending on the call order.
#
# Based on perlLDAP-1.4 code, I did heavy modification to be usefull
# with my new Entry. Originaly it was part of the Conn class, but
# I don't like way how multiple searches on same ld are done in perlLDAP-1.4
# so I created this class and moved some code here.
#
sub nextEntry {
  my $self = shift;
  my (%entry, @vals);
  my ($attr, $lcattr, $ldentry, $berv, $dn, $count);
  my ($ber) = \$berv;

  my $entry = new myPerlLDAP::entry;
  $entry->owner($self->owner);

  if ($self->{"ldfe"} == 1) {
    return unless defined($self->{"ldres"});

    $self->{"ldfe"} = 0;
    $ldentry = ldap_first_entry($self->{"ld"}, $self->{"ldres"});
    $self->{"ldentry"} = $ldentry;
  } else {
    return unless defined($self->{"ldentry"});

    $ldentry = ldap_next_entry($self->{"ld"}, $self->{"ldentry"});
    $self->{"ldentry"} = $ldentry;
  };

  if (! $ldentry) {
    if (defined($self->{"ldres"})) {
      ldap_msgfree($self->{"ldres"});
      undef $self->{"ldres"};
    }
    return undef;
  };

  $dn = ldap_get_dn($self->{"ld"}, $self->{"ldentry"});
  $entry->dn($dn);

  $attr = ldap_first_attribute($self->{"ld"}, $self->{"ldentry"}, $ber);
  $entry->clearModifiedFlags;
  return $entry unless $attr;

  $lcattr = lc $attr;
  @vals = ldap_get_values_len($self->{"ld"}, $self->{"ldentry"}, $attr);
  $self->addValues2Entry($entry, $lcattr, \@vals);

  $count = 1;
  while ($attr = ldap_next_attribute($self->{"ld"},
				     $self->{"ldentry"}, $ber)) {
    $lcattr = lc $attr;
    @vals = ldap_get_values_len($self->{"ld"}, $self->{"ldentry"}, $attr);

    $self->addValues2Entry($entry, $lcattr, \@vals);

    $count++;
  };

  ldap_ber_free($ber, 0) if $ber;

  $entry->clearModifiedFlags;
  return $entry;
};

# Return count of returned entries
sub count {
  my $self = shift;

  return ldap_count_entries($self->{"ld"}, $self->{"ldres"});
};

sub owner {
  my $self = shift;

  if (@_) {
    return $self->{OWNER} = shift;
  } else {
    return $self->{OWNER};
  };
};
