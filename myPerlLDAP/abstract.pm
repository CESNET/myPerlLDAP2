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

# This class contain abstract class myPerlLDAP::abstract, it implements
# error and errorMessage for all other classes in myPerlLDAP module.

package myPerlLDAP::abstract;

use strict;
use Carp;
use vars qw($_D $AUTOLOAD);
use perlOpenLDAP::API 1.4 qw(ldap_err2string
			     LDAP_SUCCESS);

$_D = 1;

my %fields = (
	      debug       => $_D,
	      error       => LDAP_SUCCESS,
	     );

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my %FIELDS = %fields;

  my $self = bless {_permitted_fields => \%FIELDS, %fields}, $class;

  if ($_D >= 10) {
    carp("$class created");
  };

  return $self;
};

sub errorMessage {
  my $self = shift;

  return ldap_err2string($self->error);
};

sub AUTOLOAD {
  my $self = shift;
  my $class = ref($self)
    or carp "cannot call method $AUTOLOAD on non reference $self";
  my $name = $AUTOLOAD;
  $name =~ s/.*://;

  if (exists $self->{_permitted_fields}->{$name}) {
    if (@_) {
      return $self->{$name} = shift;
    } else {
      return $self->{$name};
    };
  } elsif ($name eq 'DESTROY') {
    if ($self->can('DESTROY')) {
      $self->DESTROY;
    } else {
      return;
    };
  } else {
    carp "Can't access method '$name' in class $class";
  };
};
