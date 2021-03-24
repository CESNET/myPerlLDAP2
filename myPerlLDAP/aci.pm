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
#use perlOpenLDAP::API 1.5 qw(/.+/);
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

# mapping from DS 389 names to Sun One names
# http://www.redhat.com/docs/manuals/dir-server/8.1/admin/Viewing_the_ACIs_for_an_Entry-Get_Effective_Rights_Control.html
# http://docs.sun.com/app/docs/doc/820-2491/bcaoh?l=ru&a=view
my $ds389_Sun1 = {
		  # attribute level
		  'r' => 'read',
		  's' => 'search',
		  'w' => 'write',
		  'o' => 'delete',
		  'c' => 'compare',
		  'W' => 'self-write',
		  'O' => 'self-delete',
		  # entry level
		  'a' => 'add',
		  'd' => 'delete',
		  'n' => 'rename_dn',
		  'v' => 'read',
		 };

sub initFromHash389 {
    my $self = shift;
    my $hash = shift;

    $self->{_aci} = {};
    $self->{_aci}->{entry} = {};
    $self->{_aci}->{attributes} = {};

    # aclrights:none, objectClass:rsc, uid:rsc, userPassword:wo, cn:rsc, taildegree:rscwo, headdegree:rscwo
    my $any_edit = 0;
    foreach my $rights (@{$hash->{attributelevelrights}}) {
	foreach my $one_a_rights (split(/ *, */, $rights)) {
	    my ($attribute, $rights) = split(/:/, $one_a_rights);
	    next if ($rights eq 'none');
	    foreach my $permision (split(//, $rights)) {
		$self->_aci->{attributes}->{lc $attribute}->{$ds389_Sun1->{$permision}}=1;
		$any_edit = 1 if ($permision =~ /w/i);
	    };
	};
    };

    foreach my $rights (@{$hash->{entrylevelrights}}) {
	next if ($rights eq 'none');
	foreach my $permision (split(//, $rights)) {
	    $self->_aci->{entry}->{$ds389_Sun1->{$permision}}=1;
	};
    };
    $self->_aci->{entry}->{write}=1 if ($any_edit);
};

sub init {
  my $self = shift;
  my $entry = shift;

  my %hash;
  if ($entry) {
      $hash{attributelevelrights} = [$entry->get_value('attributeLevelRights')];
      $hash{entrylevelrights} = [$entry->get_value('entryLevelRights')];

      $self->initFromHash389(\%hash);
  };

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

  return undef if (!defined($self->_aci));
  return undef if (!defined($self->_aci->{attributes}->{$attribute}));
  return undef if (!defined($self->_aci->{attributes}->{$attribute}->{$mode}));
  return $self->_aci->{attributes}->{$attribute}->{$mode};
};

sub dump {
  my $self = shift;

  return Dumper($self->_aci);
};

1;
