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

package myPerlLDAP::entry;

use strict;
use Carp;

use perlOpenLDAP::API qw(LDAP_SUCCESS LDAP_NO_SUCH_ATTRIBUTE
			 LDAP_ALREADY_EXISTS);
use myPerlLDAP::abstract;
use myPerlLDAP::attribute;
use myPerlLDAP::utils qw(quote4XML quote4HTTP);

use vars qw($AUTOLOAD @ISA %fields);

@ISA = ("myPerlLDAP::abstract");

# TODO:
# - renaming atributes
# - change DN


# Debug levels:
#  1 ... warnings about nasty class usage
# 10 ... excution of some methods

%fields = (
	   dn          => undef,
	   debug       => 1,
	   owner       => undef,
	   attrData    => {},
	   attrOrder   => [],
	   attrChanges => [],
	   attrInit    => {},
	   attrMap     => {},
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
  $self->init(@_);

  return $self;
};

sub init {
  my $self = shift;
  my $args = shift;

  $self->attrData({});
  $self->clearModifiedFlags;

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
# Methods for work with attributes
# #############################################################################

# #############################################################################
# Removes attribute(s) by it's name
#
# Input: scalar, array, arrayref
#
# Output: count of removed attrs
#
# Error code is set to LDAP_NO_SUCH_ATTRIBUTE if one of attr wasn't in entry.

sub removeAttr {
  my $self = shift;
  my $removedCounter = 0;

  $self->error(LDAP_SUCCESS);

  while (my $attr = shift) {
    my @a;
    if ($attr eq 'ARRAY') { @a = @$attr } else { @a = ($attr) };
    foreach my $a (@a) {
      $a = lc $a;
      if ($self->attr($a)) {
	delete $self->attrData->{lc $a};
	push @{$self->attrChanges}, (lc "-$a");
	my @changes = grep(!/^$a$/, @{$self->attrOrder});
	$self->attrOrder(\@changes);
	$removedCounter++;
      } else {
	$self->error(LDAP_NO_SUCH_ATTRIBUTE);
      };
    };
  };

  return $removedCounter;
}; # removeAttr ---------------------------------------------------------------

# #############################################################################
# Add attribute(s) to entry
#
# Input: blessed scalar, array of blessed scalars, arrayref to ...
#
# Output: count of added atributes
#
# Error code is set to LDAP_ALREADY_EXISTS if one of attrs was already in
# entry.

sub addAttr {
  my $self = shift;
  my $addedCounter = 0;

  while (my $attr = shift) {
    my @a;
    if ($attr eq 'ARRAY') { @a = @$attr } else { @a = ($attr) };
    foreach my $a (@a) {
      if (defined($self->attr($a->name))) {
	$self->error(LDAP_ALREADY_EXISTS);
      } else {
	$a->owner($self);
	push @{$self->attrOrder}, (lc $a->name);
	push @{$self->attrChanges}, (lc "+".$a->name);
	$self->attrData->{lc $a->name}=$a;
	# object will be added to ATTR_ADDED so is useless to be marked
	# as modified because it will be writen to an LDAP db completely
	# again
	$self->attrData->{lc $a->name}->clearModifiedFlag;
	$addedCounter++;
      };
    };
  };

  $self->error(LDAP_SUCCESS) if ($self->error != LDAP_ALREADY_EXISTS);

  return $addedCounter;
}; # addAttr ------------------------------------------------------------------

# #############################################################################
# Return myPerlLDAP::attribute class by it's name
#
# Input: name of required attribute
#
# Output: count of added atributes
#
# Error code is set to LDAP_NO_SUCH_ATTRIBUTE if one of attrs was already in
# entry.

sub attr {
  my $self = shift;
  my $attr = lc shift;

  $self->error(LDAP_SUCCESS);

  if (defined($self->attrData->{$attr})) {
    return $self->attrData->{$attr};
  } else {
    $self->error(LDAP_NO_SUCH_ATTRIBUTE);
    return undef;
  };
}; # attr ---------------------------------------------------------------------

# #############################################################################
# Return ordered attribute names list, order is defined by user
#
# Input: none
#
# Output: arrayref of attr names
#

sub attrList {
  my $self = shift;

  $self->error(LDAP_SUCCESS);

  my @out = @{$self->attrOrder};
  return \@out;
}; # attrList -----------------------------------------------------------------

# #############################################################################
# Methods for exporting content of entry
# #############################################################################

# #############################################################################
# Return arrayref of ldif of entry
#
# Input: none
#
# Output: arrayref of ldif of entry
#

sub LDIF {
  my $self = shift;

  $self->error(LDAP_SUCCESS);

  my ($attr, $value);
  my (@out);

  # TODO: dn, objectclasses, potom ten prvni z dn (RDN)
  push @out, ("dn: ".$self->dn);
  foreach $attr (@{$self->attrList}) {
    if (defined($self->attr($attr)) and ($self->attr($attr)->count)) {
      push @out, @{$self->attr($attr)->LDIF};
    }; # else: Attribute which have no value doesn't exists.
  };

  return \@out;
}; # LDIF ---------------------------------------------------------------------

# #############################################################################
# Return ldif of entry
#
# Input: none
#
# Output: ldif of entry

sub LDIFString {
  my $self = shift;

  $self->error(LDAP_SUCCESS);

  return join("\n", @{$self->LDIF})."\n";
}; # LDIFString ---------------------------------------------------------------

# #############################################################################
# Return arrayref of XML (based on dsml) of entry
#
# Input: none
#
# Output: arrayref of XML of entry

sub XML {
  my $self = shift;
  my @ret;
  my $attr;

  push @ret, "<dsml:entry dn=\"".quote4XML($self->dn)."\" urldn=\"".quote4XML(quote4HTTP($self->dn))."\" xmlns:dsml=\"http://www.dsml.org/DSML\">";
  foreach $attr (@{$self->attrList}) {
    push @ret, map { "  $_"} @{$self->attr($attr)->XML};
  };
  push @ret, "</dsml:entry>";

  return \@ret;
}; # XML ----------------------------------------------------------------------

# #############################################################################
# Return XML of entry
#
# Input: optional argument ident for producing nice output
#
# Output: XML of entry

sub XMLString {
  my $self = shift;
  my $ident = shift;

  $ident = "" unless $ident;

  return join("\n", map { "$ident$_" } @{$self->XML})."\n";
};

# #############################################################################
# Methods for work with attribute values. This is against my OO architecture
# but it's much more comfortable to work with attribute values in this way
# because it reduces count of if(!defined...
# #############################################################################

# #############################################################################
# Add values to entry's attribute, if necessary create attribute too.
#
# Input: #1 name of required attribute to add to
#        #2 value or arrayref of values
#        #3 optional sub-type attribute
#
# Output: count of added values (retrieved from attribute->add method)
#
# It will refuse create attribute, if you will not pass any value.
#
# Error code is set by attribute->add() method or by entry->addAttr depending
# which one will return error!=LDAP_SUCESS, if any. This method allows
# setting values of readOnly attributes eg. objectClass but only when
# THIS method created that attribute. This is necessary for searchResult's
# method nextEntry ... and it's fine for me when I'm creating new entry
# from scratch in memory before adding it to LDAP.

sub addValues {
  my $self = shift;
  my $attrName = lc shift;
  my $values = shift;
  my $subType = shift;
  my $attr = $self->attr($attrName);
  my $attrIsNew = 0;

  $self->error(LDAP_SUCCESS);

  return 0 if (!defined($values));

  if (!defined($attr)) {
    my $class;

    if (defined($self->attrMap->{$attrName})) {
      $class = $self->attrMap->{$attrName};
    } else {
      $class = myPerlLDAP::attribute::classNamePrefix().$attrName;
      if (eval "require $class" ) {
      } else {
	if (($myPerlLDAP::attribute::_D) and ($attrName ne "")) {
	  carp("Can't load module \"$class\" attribute \"$attrName\" created as \"myPerlLDAP::attribute\"");
	};
	$class = 'myPerlLDAP::attribute';
      };
    };

    $attr = $class->new($attrName);
    $attr->owner($self);
    $attrIsNew = 1;
  };

  my $res = 0;
  my $RO = $attr->readOnly;
  if ($attrIsNew and $RO) {
    $attr->readOnly(0);
  };

  $values = [$values] if (ref($values) ne 'ARRAY');

  $res = $attr->addValues($values, $subType);
  $self->error($attr->error);

  if ($attrIsNew and $RO) {
    $attr->readOnly(1);
  };

  if ($attrIsNew) {
    my $oldError = $self->error;
    $self->addAttr($attr);
    $self->error($oldError) if ($self->error==LDAP_SUCCESS);
  };

  return $res;
}; # addValues ----------------------------------------------------------------

# #############################################################################
# Set values to entry's attribute, if necessary create attribute too. For more
# info see addValues.

sub setValues {
  my $self = shift;
  my $attrName = lc shift;

  my $attr = $self->attr($attrName);
  if (!defined($attr)) {
    return $self->addValues($attrName, @_);
  } else {
    $attr->clearValues;
    return $self->addValues($attrName, @_);
  };
}; # setValues ----------------------------------------------------------------

# #############################################################################
# Remove values from entry's attribute, if attribute isn't present return
# LDAP_NO_SUCH_ATTRIBUTE.

sub removeValues {
  my $self = shift;
  my $attrName = lc shift;

  my $attr = $self->attr($attrName);

  if (!defined($attr)) {
    $self->error(LDAP_NO_SUCH_ATTRIBUTE);
    return 0;
  };

  return $attr->remove(@_);
}; # removeValues -------------------------------------------------------------

# #############################################################################
# Get values of the entry's attribute, if attribute isn't present set error
# LDAP_NO_SUCH_ATTRIBUTE and return empty arrayref

sub getValues {
  my $self = shift;
  my $attrName = lc shift;

  my $attr = $self->attr($attrName);

  if (!defined($attr)) {
    $self->error(LDAP_NO_SUCH_ATTRIBUTE);
    return [];
  };

  return $attr->getValues(@_);
}; # getValues ----------------------------------------------------------------

# #############################################################################
# Get values of the entry's attribute which match regular expresion. If
# attribute isn't present set error LDAP_NO_SUCH_ATTRIBUTE and return
# empty arrayref

sub matchValues {
  my $self = shift;
  my $attrName = lc shift;

  my $attr = $self->attr($attrName);

  if (!defined($attr)) {
    $self->error(LDAP_NO_SUCH_ATTRIBUTE);
    return [];
  };

  return $attr->matchValues(@_);
}; # matchValues --------------------------------------------------------------

sub makeAddRecord {
  my $self = shift;
  my %rec;

  my $attr;
  foreach $attr (@{$self->attrList}) {
    if (defined($self->attr($attr)) and ($self->attr($attr)->count)) {
      %rec = (%rec, %{$self->attr($attr)->makeModificationRecord('ab')});
    }; # else: Attribute which have no value doesn't exists.
  };

  return \%rec;
};

sub clearModifiedFlags {
  my $self = shift;

  $self->attrChanges([]);
  $self->attrInit({});

  my $attr;
  foreach $attr (@{$self->attrList}) {
    $self->attr($attr)->clearModifiedFlag;
    $self->attrInit->{$attr}=1;
  };
};

sub isModified {
  my $self = shift;

  return 1 if @{$self->attrChanges};
  foreach my $attr (@{$self->attrList}) {
    return 1 if $self->attr($attr)->modified;
  };

  return 0;
};

sub makeModificationRecord {
  my $self = shift;

  my %rec;
  my %delete;
  my %replace;
  my %add;

  my ($attr, $x);
  foreach $x (@{$self->attrChanges}) {

    if ($x =~ /^\-(.*)$/) { # delete
      $attr = $1;
      if ($self->attrInit->{$attr}) {
	$delete{$attr}=1;
	delete $add{$attr} if (exists($add{$attr}));
	delete $replace{$attr} if (exists($replace{$attr}));
      }; # else -> attribute isn't in LDAP database it was added and deleted
         # someone who is using myPerlLDAP::entry, we can't pass this to
         # server othervise all requests will fail
    };

    if ($x =~ /^\+(.+)$/) { # add
      $attr = $1;

      if ($self->attrInit->{$attr}) {
	# we can't add attribute which is in LDAP database, we have to
	# overwrite it. This can happen if user first deletes attribute
	# and then add it again.
	$replace{$attr}=1;
	delete $add{$attr} if (exists($add{$attr}));
	delete $delete{$attr} if (exists($delete{$attr}));
      } else {
	# this is pure add
	$add{$attr}=1;
	delete $replace{$attr} if (exists($replace{$attr}));
	delete $delete{$attr} if (exists($delete{$attr}));
      };
    };
  };

  foreach $attr (keys %delete) {
    die "This should never happen" if (defined($rec{$attr}));

    $rec{$attr}->{rb}=[];
  };

  foreach $attr (keys %add, keys %replace) {
    die "This should never happen" if (defined($rec{$attr}));

    %rec = (%rec, %{$self->attr($attr)->makeModificationRecord('rb')});
  };

  foreach my $attrName (@{$self->attrList}) {
    if (($self->attr($attrName)->getModifiedFlag()) and
	(!defined($rec{$attrName}))) {
      # TODO: This is nasty. I'm replacing whole attribute, but now
      # I don't have much time ... to do better implementation I will
      # need modify myPerlLDAP::attribute to be able produce modificaion
      # record for this.
      %rec = (%rec, %{$self->attr($attrName)->makeModificationRecord('rb')});
    };# else -> attribute was added as new and after that it was modified
      # I not process it here because it is being added as new attr ...
  };

  return \%rec;
};


1;
