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
	   owner         => undef
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

  $self->{VALUES} = undef;
  $self->setModifiedFlag();
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

  # This attribute is only single value and value is set
  if (($self->singleValue) and (scalar @{$self->getValues($type)})) {
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
      } else {
	my @valElem = ($self->checkFixLength($value), $type);
	push @values, \@valElem;
	$addCounter++;
      };
    };
  };

  if ($addCounter) {
    push @{$self->{VALUES}}, (@values);
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

  foreach my $value (@{$self->{VALUES}}) {
    my ($v,$t) = @$value;
    $t = "" unless $t;
    if ($t eq $type) {
      push @values, ($v);
    };
  };

  return \@values;
}; # getValues ----------------------------------------------------------------


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
};

sub makeModificationRecord {
  my $self = shift;
  my $mode = shift;
  my %res;

  foreach my $type (@{$self->types}) {
    my $TYPE = "";
    $TYPE = ";$type" if ($type);
    if ($res{$self->name."$TYPE"}->{$mode}) {
    } else {
      $res{$self->name."$TYPE"}->{$mode} = $self->getValues($type);
    };
  };

  return \%res;
};

sub className {
  my $self = shift;

  my $name = ref($self);
  $name =~ s/.*:://;

  return $name;
};

sub classNamePrefix {
  return 'myPerlLDAP::attribute::';
};

sub xmlAttributeArgs {
  return undef;
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
      push @ret, $self->name."$TYPE: $value";
    };
  };

  return \@ret;
};

1;
