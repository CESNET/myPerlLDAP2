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

package myPerlLDAP::attribute;

use strict;

use Carp;
use perlOpenLDAP::API qw(LDAP_SUCCESS LDAP_CONSTRAINT_VIOLATION
			 LDAP_TYPE_OR_VALUE_EXISTS LDAP_NO_SUCH_OBJECT);
use myPerlLDAP::attribute;
use MIME::Base64;
use myPerlLDAP::utils qw(quote4XML quote4HTTP isBinary);
use Storable qw(dclone);
use Data::Dumper;
use vars qw($AUTOLOAD @ISA %fields);

@ISA = ("myPerlLDAP::abstract");

# Debug levels:
#  1 ... warnings about nasty class usage
# 10 ... excution of some methods

%fields = (
	   description   => undef,
	   OID           => undef,
	   equality      => undef,
	   syntax        => undef,
	   subStr        => undef,
	   ordering      => undef,
	   usage         => undef,
	   length        => undef,
	   singleValue   => 0,     # By default multiple values
	   readOnly      => 0,     # By default modifyable?
	   debug         => 1,
	   modified      => undef,
	   name          => undef,
	   owner         => undef,
	   sortingEnabled=> undef,
	   _sorted       => 1,
	   showURL       => undef,
	  );

=head1 NAME

attribute

=head1 DESCRIPTION

=item new

bla bla

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $requestedClass = lc shift;
  my %FIELDS = %fields;

  my $self = bless $class->SUPER::new(@_), $class;
  foreach my $element (keys %fields) {
    $self->{_permitted_fields}->{$element} = $fields{$element};
  };
  @{$self}{keys %fields} = values %fields;

  $self->name($requestedClass);
  $self->init;

  if ($self->debug >= 10) {
    carp("$self created");
  };

  return $self;
};

=item init

bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla

bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla bla

=cut

sub init {
  my $self = shift;

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

#sub AUTOLOAD {
#  my $self = shift;
#  my $class = ref($self)
#    or carp "cannot call method $AUTOLOAD on non reference $self";
#  my $name = $AUTOLOAD;
#  $name =~ s/.*://;
#
#  if (exists $self->{_permitted_fields}->{$name}) {
#    if (@_) {
#      return $self->{$name} = shift;
#    } else {
#      return $self->{$name};
#    };
#  } elsif ($name eq 'DESTROY') {
#    if ($self->can('DESTROY')) {
#      $self->DESTROY;
#    } else {
#      return;
#    };
#  } else {
#    carp "Can't access method '$name' in class $class";
#  };
#};

sub count {
  my $self = shift;

  return 0 if (!defined($self->{VALUES}));
  return scalar @{$self->{VALUES}};
};

# #############################################################################
# Functions for work with attribute values
# #############################################################################

# #############################################################################
# Removes all values from attribute
#
# Input: none
#
# Output: none

sub clearValues {
  my $self = shift;

  $self->error(LDAP_SUCCESS);

  push @{$self->{_clearedTypes}}, @{$self->types};
  $self->{VALUES} = undef;
  $self->setModifiedFlag();
  $self->{_cleared} = 1;
  $self->{_sorted} = 1;
};

# #############################################################################
# Removes all old values and sets new one
#
# Input: see add
#
# Output: see add

sub setValues {
  my $self = shift;

  # This READ ONLY attribute we can't change it
  if ($self->readOnly) {
    carp("Attempt to change read-only object $self") if ($self->debug);
    $self->error(LDAP_CONSTRAINT_VIOLATION);
    return 0;
  };

  $self->clearValues;
  return $self->addValues(@_);
}; # setValues ----------------------------------------------------------------

# #############################################################################
# Adds new value(s) to attribute
#
# Input: value or arrayref of values
#
# Output: number of added values
#
# Error code should be LDAP_CONSTRAINT_VIOLATION:
#   1) adding to readOnly attribute such is creatorsname
#   2) adding second value to singleValue attribute
# or LDAP_TYPE_OR_VALUE_EXISTS if some value already was in attribute.

sub addValues {
  my $self = shift;
  my (@values); # Here I put values which will be finally added to
                # internal classes structures.
  my ($values); # This will be array ref of value(s) passed by user
                # to this method
  my $addCounter = 0;
  # Examine if first arg is one value (scalar) or multiple values (array ref)
  $values = $_[0];
  $values = [$_[0]] if (ref($_[0]) ne 'ARRAY');
  shift;
  # Subtype of values is optional
  my $type = shift;

  $self->error(LDAP_SUCCESS);

  # This READ ONLY attribute we can't change it
  if ($self->readOnly) {
    carp("Attempt to change read-only object $self") if ($self->debug);
    $self->error(LDAP_CONSTRAINT_VIOLATION);
    return 0;
  };

  # This attribute is only single value and value is set if
  # (($self->singleValue) and (scalar @{$self->getValues($type)})) {
  # 18.05.2004 Semik: I'm not sure if this is realy needed, but I'm
  # sure it causes multiple sorting, which is done throught getValues
  # function so removed.
  if (($self->singleValue) and ($self->count)) {
    carp(ref($self)."\->add() another value passed to single-value attribute")
      if ($self->debug);
    $self->error(LDAP_CONSTRAINT_VIOLATION);
    return 0;
  };

  foreach my $value (@$values) {
    if ($self->has($value,$type)) {
      #if ($_D || $self->debug) {
      #  carp("$self\->add() same value=\"$value\" passed to attribute");
      #};
      $self->error(LDAP_TYPE_OR_VALUE_EXISTS);
    } else {
      if ($addCounter and $self->singleValue) {
	carp("more than one value passed to singe-value attribute $self");
      } elsif (!defined($value)) {
	#warn "SKIP";
      } else {
	my @valElem = ($self->checkFixLength($value), $type);
	push @values, \@valElem;
	$addCounter++;
      };
    };
  };

  if ($addCounter) {
    push @{$self->{VALUES}}, (@values);
    $self->{_sorted} = 0;
    $self->setModifiedFlag();
  };

  return $addCounter;
}; # addValues ----------------------------------------------------------------

# #############################################################################
# Remove value(s) from attribute
#
# Input: value or arrayref of values
#
# Output: number of removed values

sub removeValues {
  my $self = shift;

  $self->error(LDAP_SUCCESS);

  # This READ ONLY attribute we can't change it
  if ($self->readOnly) {
    carp("Attempt to change read-only object $self") if ($self->debug);
    $self->error(LDAP_CONSTRAINT_VIOLATION);
    return 0;
  };

  # Examine if first arg is one value (scalar) or multiple values (array ref)
  my $values = $_[0];
  $values = [$_[0]] if (ref($_[0]) ne 'ARRAY');
  shift;
  # Subtype of values is optional
  my $type = shift;


  my $v2;
  my $removedCount = 0;

  foreach my $value (@$values) {
    my $j = 0;
    while ($j < @{$self->{VALUES}}) {
      $v2 = $self->{VALUES}->[$j];
      my @value = ($value,$type);
      if ($self->compareValues(\@value, $v2)) {
	splice (@{$self->{VALUES}}, $j, 1);
	$removedCount++;
      } else {
	$j++;
      };
    };
  };

  $self->setModifiedFlag() if ($removedCount);
  $self->error(LDAP_NO_SUCH_OBJECT) if ($removedCount != @$values);

  return $removedCount;
}; # removeValues -------------------------------------------------------------

sub getValues {
  my $self = shift;
  my $type = shift; $type = "" unless $type;
  my @values;

  $self->sortValues unless ($self->{_sorted});

  foreach my $value (@{$self->{VALUES}}) {
    my ($v,$t) = @$value;
    $t = "" unless $t;
    if ($t eq $type) {
      push @values, ($v);
    };
  };

  return \@values;
}; # getValues ----------------------------------------------------------------

sub matchValues {
  my $self = shift;
  my $expr = shift;
  my $type = shift; $type = "" unless $type;
  my @values;

  return [] if (!defined($expr));

  foreach my $value (@{$self->{VALUES}}) {
    my ($v,$t) = @$value;
    $t = "" unless $t;
    if ($t eq $type) {
      if ($v =~ /$expr/i) {
	push @values, ($v);
      };
    };
  };

  return \@values;
}; # matchValues --------------------------------------------------------------


sub has {
  my $self = shift;

  my ($v1, $v2, $values);
  # Examine if first arg is one value (scalar) or multiple values (array ref)
  if (ref($_[0]) eq "ARRAY") {
    $values = shift;
  } else {
    my @v;
    $v[0] = shift;
    $values = \@v;
  };
  my $t1 = shift;

  my $count = 0;
  if (defined($values)) {
    foreach $v1 (@$values) {
      foreach $v2 (@{$self->{VALUES}}) {
	my @v1 = ($v1, $t1);
        if ($self->compareValues(\@v1, $v2)) {
	  $count++;
	};
      };
    };
  } else {
    if ($self->debug) {
      carp("$self\->has() called without any value");
    };
    return undef;
  };

  return $count;
}; # has

sub types {
  my $self = shift;
  my %types;
  my @types;
  my $undef_type = 0;

  foreach my $value (@{$self->{VALUES}}) {
    my ($v,$t) = @$value;

    if (defined($t)) {
      $types{$t} = 1;
    } elsif (!$undef_type) {
      $undef_type = 1;
    };
  };

  @types = (sort keys %types);
  if ($undef_type) {
    unshift @types, (undef);
  };

  return \@types;
};

# TODO: Make it work corectly with matchingrules
sub compareValues {
  my $self = shift;
  my $v1 = shift;
  my $v2 = shift;

  my $t1 = lc $v1->[1]; $t1 = "" unless $t1;
     $v1 = lc $v1->[0];
  my $t2 = lc $v2->[1]; $t2 = "" unless $t2;
     $v2 = lc $v2->[0];

  if (($v1 eq $v2) and ($t1 eq $t2)) {
    #print "1: $v1;$t1 ? $v2;$t2\n";
    return 1;
  } else {
    #print "0: $v1;$t1 ? $v2;$t2\n";
    return 0;
  };
};

sub checkFixLength {
  my $self = shift;
  my $value = shift;

  if (defined($self->length)) {
    if (length($value)>$self->length) {
      if ($self->debug) {
	carp("$self\->checkFixLength() truncated value to $self->{LENGTH} length");
      };
      return substr($value, 0, $self->length);
    };
  };

  return $value;
};

sub setModifiedFlag {
  my $self = shift;

  $self->modified(1);
};

sub getModifiedFlag {
  my $self = shift;

  return $self->modified;
};

sub clearModifiedFlag {
  my $self = shift;

  $self->modified(undef);
  $self->{_VALUES} = dclone($self->{VALUES});
};

sub makeModificationRecord {
  my $self = shift;
  my $mode = shift;
  my %res;

  sub addValues2res {
    my $res    = shift;
    my $attr   = shift;
    my $mode   = shift;
    my $values = shift;

    if ((scalar @{$values} == 1) and ($values->[0] eq '') and ($mode ne 'rb')) {
      return 0;
    } else {
      $res->{$attr}->{$mode} = [] if (!defined($res->{$attr}->{$mode}));
      push @{$res->{$attr}->{$mode}}, @{$values};
      return 1;
    };
  };

  # Posible modes
  #   ab: add values to attribute
  #   db: delete values from attribute
  #   rb: replace all existing values of attribute with new one
  if ($mode eq 'ab') {
    foreach my $type (@{$self->types}) {
      my $attr = $self->name;
      $attr = "$attr;$type" if ($type);
      # TODO: 18.05.2004 Access $self->{VALUES} rather directly this
      # is causing not necesary sorting when enabled
      addValues2res(\%res, $attr, 'ab', $self->getValues($type));
    };
  } elsif (defined($self->{_cleared})) {
    #warn "$self->makeModificationRecord: Replace mode of _cleared";
    my $counter=0;
    my $addedSomething = 0;
    my %usedSubType = ();
    foreach my $val (@{$self->{VALUES}}) {
      my $attr = $self->name;
      $usedSubType{$val->[1] || ''}++;
      $attr = "$attr;$val->[1]" if ($val->[1]);
      $addedSomething = 1 if addValues2res(\%res, $attr, 'rb', [$val->[0]]);
      $counter++;
    };

    # 3. 5. 2007 - odstraneno protoze jsem funkci addValues2res
    # umoznil v pripade ze je pozadavek na zmenu v rezimu 'rb'
    # generovat zmenovy zaznam. Nize uvedeny kod nefunguval s subtypy.

    #addValues2res(\%res, $self->name, 'rb', []) if (($counter == 0) or
    #						    ($addedSomething == 0));
  } elsif ($mode eq 'rb-force') {
    foreach my $type (@{$self->types}) {
      my $attr = $self->name;
      $attr = "$attr;$type" if ($type);
      # TODO: 18.05.2004 Access $self->{VALUES} rather directly this
      # is causing not necesary sorting when enabled
      addValues2res(\%res, $attr, 'rb', $self->getValues($type));
    };
  } else {
    # Values to be deleted (_VALUES - VALUES)
    foreach my $_val (@{$self->{_VALUES}}) {
      my $m = 1;
      foreach my $val (@{$self->{VALUES}}) {
	my $_t = $_val->[1] || '';
	my $t = $val->[1] || '';
	$m = 0 if (($_val->[0] eq $val->[0]) and ($_t eq $t));
      };
      if ($m) {
        my $attr = $self->name;
	$attr = "$attr;$_val->[1]" if ($_val->[1]);
        #$res{$attr}->{db} = $_val->[0];
	addValues2res(\%res, $attr, 'db', [$_val->[0]]);
      };
    };
    # Values to be added (VALUES - _VALUES)
    foreach my $_val (@{$self->{VALUES}}) {
      my $m = 1;
      foreach my $val (@{$self->{_VALUES}}) {
	my $_t = $_val->[1] || '';
	my $t = $val->[1] || '';
	$m = 0 if (($_val->[0] eq $val->[0]) and ($_t eq $t));
      };
      if ($m) {
	my $attr = $self->name;
	$attr = "$attr;$_val->[1]" if ($_val->[1]);
	#$res{$attr}->{ab} = $_val->[0];
	addValues2res(\%res, $attr, 'ab', [$_val->[0]]);
      };
    };
    #warn Dumper("----------------------------------------------------------",
#		"NAME",     $self->name,
#		"MODIFIED", $self->modified,
#		"CLEARED",  $self->{_cleared},
#		"_VALUES",  $self->{_VALUES},
#		"VALUES",   $self->{VALUES});
  };

  return \%res;
};

sub className {
  my $self = shift;

  my $name = ref($self);
  $name =~ s/.*:://;

  return $name;
};

sub showURL {
  my $self = shift;

  if (@_) {
    return $self->{showURL} = shift;
  };

  return $::c{ref $self}{showURL} if defined($::c{ref $self}{showURL});
  return $self->{showURL};
};

sub xmlAttributeArgs {
  my $self = shift;

  if ($self->showURL) {
    return ' url="'.quote4XML($self->showURL).'"';
  } else {
    return undef;
  };
};

sub classNamePrefix {
  return 'myPerlLDAP::attribute::';
};

sub xmlValueArgs {
  return undef;
};

sub XML {
  my $self = shift;
  my @ret;
  my $value;

  if ($self->name eq 'objectclass') {
    push @ret, '<dsml:objectclass>';
    foreach $value (@{$self->getValues}) {
      push @ret, "  <dsml:oc-value>$value</dsml:oc-value>";
    };
    push @ret, '</dsml:objectclass>';
  } else {
    my $attrArgs ='';
    $attrArgs = $self->xmlAttributeArgs if ($self->xmlAttributeArgs);
    push @ret, "<dsml:attr name=\"".$self->name."\"$attrArgs>";
    foreach my $type (@{$self->types}) {
      foreach $value (@{$self->getValues($type)}) {
	my $TYPE = "";
	$TYPE = " type=\"$type\"" if ($type);

	my $valueArgs ='';
	$valueArgs = $self->xmlValueArgs($value)
	  if ($self->xmlValueArgs($value));

	$value = $self->humanReadableForm($value)
	  if ($self->can('humanReadableForm'));

	$value = quote4XML($value);

	push @ret, "  <dsml:value$TYPE$valueArgs>$value</dsml:value>";
      };
    };
    push @ret, "</dsml:attr>";
  };

  return \@ret;
};

sub LDIF {
  my $self = shift;
  my @ret;
  my $value;

  foreach my $type (@{$self->types}) {
    foreach $value (@{$self->getValues($type)}) {
      my $TYPE = "";
      $TYPE = ";$type" if ($type);

      if (isBinary($value)) {
	my @enc = split("\n", encode_base64($value));
	push @ret, $self->name."$TYPE\:\: ".join("\n ", @enc);
      } else {
	push @ret, $self->name."$TYPE: $value";
      };
    };
  };

  return \@ret;
};

sub sortValues {
  my $self = shift;

  return 1 unless $self->sortingEnabled;

  $self->sortValuesInit;

  $self->_sortValues;

  $self->sortValuesDone;
  $self->{_sorted} = 1;
};

sub _sortValues {
};

sub sortValuesInit {
  my $self = shift;
  $self->{_SV} = {};
};

sub sortValuesDone {
  my $self = shift;
  delete $self->{_SV};
};

1;
