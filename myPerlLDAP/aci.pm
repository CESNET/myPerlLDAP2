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

package myPerlLDAP::aci;

use strict;
use Carp;
use Data::Dumper;
use perlOpenLDAP::API 1.5 qw(/.+/);
use myPerlLDAP::abstract;
use myPerlLDAP::attribute;
use myPerlLDAP::utils qw(quote4XML quote4HTTP);

use vars qw($AUTOLOAD @ISA %fields);

@ISA = ("myPerlLDAP::abstract");

# Debug levels:
#  1 ... warnings about nasty class usage
# 10 ... excution of some methods

%fields = (
	   dn          => undef,
	   debug       => 1,
	   _aci        => undef,
	   owner       => undef,
	  );

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $self = bless $class->SUPER::new(@_), $class;

  if ($self->debug >= 10) {
    carp("$class created");
  };

  foreach my $element (keys %fields) {
    $self->{_permitted_fields}->{$element} = $fields{$element};
  };
  @{$self}{keys %fields} = values %fields;

  foreach my $field (keys %fields) {
    if (ref($fields{$field}) eq "HASH") {
      my %hash = %{$fields{$field}};
      $self->{$field} = \%hash;
    };
    if (ref($fields{$field}) eq "ARRAY") {
      my @array = @{$fields{$field}};
      $self->{$field} = \@array;
    };
  };

  $self->init(@_) if (@_);

  return $self;
};

sub _buildACIHash {
  my $aciVal = shift;

  my @aciElements = split(/,/, $aciVal);
  my %aci;
  foreach my $aciElement (@aciElements) {
    if ($aciElement =~ /^([A-Z\_a-z]+):([0-1])$/) {
      $aci{$1} = $2;
      $aci{$1} = undef if ($2 == 0);
    } else {
      die "myPerlLDAP::aci::_buildACIHash: I don't understand to aciElement=\"$aciElement\". This should not happen.";
    };
  };

  return \%aci;
};

sub initFromHash {
  my $self = shift;
  my $hash = shift;

  $self->{_aci} = {};
  $self->{_aci}->{entry} = {};
  $self->{_aci}->{attributes} = {};

  foreach my $attr (keys %{$hash}) {
    my @vals = @{$hash->{$attr}};

    die "myPerlLDAP::aci::initFromHash: What?! More than one ACI value? I'm not ready for this" unless (scalar @vals ==1);

    if ($attr =~ /^aclrights;entrylevel$/) {
      $self->{_aci}->{entry} = _buildACIHash($vals[0]);
    } elsif ($attr =~ /^aclrights;attributelevel;(.+)$/) {
      $self->{_aci}->{attributes}->{$1} = _buildACIHash($vals[0]);
    };
  };
};

sub init {
  my $self = shift;
  my $ld = shift;
  my $res = shift;

  my %hash;
  my $entry = ldap_first_entry($ld,$res);
  my $ber;
  my $attr = lc ldap_first_attribute($ld,$entry,$ber);
  while ($attr) {
    my @vals = ldap_get_values($ld, $entry, $attr);

    $hash{$attr} = \@vals;
    $attr = lc ldap_next_attribute($ld, $entry, $ber);
  };

  $self->initFromHash(\%hash);

  die "More than result to search with LDAP_SCOPE_BASE?! Imposible"
    if (ldap_next_entry($ld,$res)>0);

  if ($self->debug >= 10) {
    carp("$self initiated");
  };
};

sub DESTROY {
  my $self = shift;

  if ($self->debug >= 10) {
    carp("$self destroyed");
  };
};

# #############################################################################

sub e {
  my $self = shift;
  my $mode = lc shift;

  return undef if (!defined($self->_aci->{entry}->{$mode}));
  return $self->_aci->{entry}->{$mode};
};

sub a {
  my $self = shift;
  my $attribute = lc shift;
  my $mode = lc shift;

  return undef if (!defined($self->_aci->{attributes}->{$attribute}));
  return undef if (!defined($self->_aci->{attributes}->{$attribute}->{$mode}));
  return $self->_aci->{attributes}->{$attribute}->{$mode};
};

1;
