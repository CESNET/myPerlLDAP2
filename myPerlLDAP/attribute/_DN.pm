package myPerlLDAP::attribute::_DN;

use strict;
use myPerlLDAP::attribute;

use vars qw($VERSION @ISA);


$VERSION = "0.5.0";

@ISA = ("myPerlLDAP::attribute");

sub humanReadableForm {
  my $self = shift;
  my @val;

  foreach my $val (@{$self->get(@_)}) {
    $val =~ s/.*?=//;
    $val =~ s/,.*//;
    push @val, $val;
  };

  # warn "ENTRY: ".$self->owner;
  # warn "CONN: ".$self->owner->owner;

  return \@val;
};

1;
