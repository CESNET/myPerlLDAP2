#!/usr/bin/perl -w

package myPerlLDAP::Attribute;

use strict;

use myPerlLDAP::Attribute::_OID;

use Carp;
use vars qw($VERSION  $_D);

$VERSION = "0.0.1";

# Debug levels:
#  1 ... warnings about nasty class usage (trying set value of read-only attr ...)
# 10 ... excution of some methods
$_D = 1;

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $requestedClass = lc shift;
  my $self  = {};

  if (eval "require myPerlLDAP::Attribute::$requestedClass" ) {
    $class = "myPerlLDAP::Attribute::$requestedClass";
  } else {
    if ($_D || $self->{_D}) {
      carp("$_D Can't load module \"myPerlLDAP::Attribute::$requestedClass\" attribute \"$requestedClass\" created as \"$class\"");
    };
  };

  bless($self, $class);

  $self->{NAME} = $requestedClass;
  $self->init();

  if (($_D >= 10) || ($self->{_D} >= 10)) {
    carp("$self created");
  };

  return $self;
};

sub init {
  my $self = shift;

  # TODO: jako jedno prirazeni
  $self->{DESC} = undef;
  $self->{OID} = undef;
  $self->{EQUALITY} = undef;
  $self->{SYNTAX} = undef;
  $self->{SUBSTR} = undef;
  $self->{ORDERING} = undef;
  $self->{USAGE} = undef;
  $self->{LENGTH} = undef;
  $self->{SINGEVALUE} = 0; # By default multiple values
  $self->{READONLY} = 0;   # By default modifyable?

  $self->{_D} = $_D;

  $self->{VALUES} = undef;
  $self->{MODIFIED} = undef;

  if (($_D >= 10) || ($self->{_D} >= 10)) {
    carp("$self initiated");
  };
};

sub DESTROY {
  my $self = shift;

  if (($_D >= 10) || ($self->{_D} >= 10)) {
    carp("$self destroyed");
  };
};

sub debug {
  my $self = shift;

  if (ref($self)) {
    $self->{_D} = shift;
  } else {
    $_D = shift;
  };
};

sub count {
  my $self = shift;

  if (!defined($self->{VALUES})) {
    return 0;
  };

  return scalar @{$self->{VALUES}};
};

sub set {
  my $self = shift;

  if ($self->isReadOnly) {
    # This READ ONLY attribute we can't change it
    if ($_D || $self->{_D}) {
      carp("Attempt to change read-only object $self");
    };
    return undef;
  };

  if (!(scalar @_)) {
    # No value suplied
    if ($_D || $self->{_D}) {
      carp("$self\->set() called without any value");
    };
    return undef;
  };

  my (@values, $value, $values);
  if (ref($_[0]) eq "ARRAY") {
    $values = $_[0];
  } else {
    $values = \@_;
  };

  foreach $value (@$values) {
    push @values, $self->checkFixLength($value);
    if (($self->isSingleValue) and (scalar @values)) {
      # This attribute is only single value so we take only first
      if ((@$values > 1) and ($_D || $self->{_D})) {
	carp("more than one value passed to singe-value attribute $self");
	goto ENDFOREACH;
      };
    };
  };
 ENDFOREACH:
  $self->{VALUES}=\@values;

  $self->setModifiedFlag();

  return $self->{VALUES};
};

sub add {
  my $self = shift;

  if ($self->isReadOnly) {
    # This READ ONLY attribute we can't change it
    if ($_D || $self->{_D}) {
      carp("Attempt to change read-only object $self");
    };
    return undef;
  };

  if (!(scalar @_)) {
    # No value suplied
    if ($_D || $self->{_D}) {
      carp("$self\->add() called without any value");
    };
    return undef;
  };

  if (($self->isSingleValue) and (scalar @{$self->{VALUES}})) {
    # This attribute is only single value and value is set
    if ($_D || $self->{_D}) {
      carp("$self\->add() another value passed to single-value attribute");
    };
    return undef;
  };

  my (@values, $value, $values);
  if (ref($_[0]) eq "ARRAY") {
    $values = $_[0];
  } else {
    $values = \@_;
  };

  foreach $value (@$values) {
    if ($self->has($value)) {
      if ($_D || $self->{_D}) {
	carp("$self\->add() same value=\"$value\" passed to attribute");
      };
    } else {
      push @values, $self->checkFixLength($value);
    };
    if (($self->isSingleValue) and (scalar @values)) {
      # This attribute is only single value so we take only first
      if ((@$values > 1) and ($_D || $self->{_D})) {
	carp("more than one value passed to singe-value attribute $self");
	goto ENDFOREACH;
      };
    };
  };
 ENDFOREACH:

  push @{$self->{VALUES}}, (@values);

  $self->setModifiedFlag();

  return $self->{VALUES};
};

# Removes list of values from atribute, returns 
sub remove {
  my $self = shift;

  if ($self->isReadOnly) {
    # This READ ONLY attribute we can't change it
    if ($_D || $self->{_D}) {
      carp("Attempt to change read-only object $self");
    };
    return 0;
  };

  my ($v1, $v2, $values);
  if (ref($_[0]) eq "ARRAY") {
    $values = $_[0];
  } else {
    $values = \@_;
  };

  my $count = 0;
  if (defined($values)) {
    foreach $v1 (@$values) {
      my $j = 0;
      while ($j < @{$self->{VALUES}}) {
	$v2 = $self->{VALUES}->[$j];
        if ($self->compareValues($v1, $v2) == 0) {
	  #print "$j: \"$v1\"=\"$v2\"\n";
	  splice (@{$self->{VALUES}}, $j, 1);
	  $count++;
	} else {
	  $j++;
	};
      };
    };
  } else {
    $self->{VALUES}=undef;
  };

  $self->setModifiedFlag();

  return $count;
}; # remove

sub has {
  my $self = shift;

  my ($v1, $v2, $values);
  if (ref($_[0]) eq "ARRAY") {
    $values = $_[0];
  } else {
    $values = \@_;
  };

  my $count = 0;
  if (defined($values)) {
    foreach $v1 (@$values) {
      foreach $v2 (@{$self->{VALUES}}) {
        if ($self->compareValues($v1, $v2) == 0) {
	  #print "$j: \"$v1\"=\"$v2\"\n";
	  $count++;
	};
      };
    };
  } else {
    if ($_D || $self->{_D}) {
      carp("$self\->has() called without any value");
    };
    return undef;
  };

  return $count;
}; # has

sub get {
  my $self = shift;

  return $self->{VALUES};
}; # get

# TODO: Make it work corectly with matchingrules
sub compareValues {
  my $self = shift;
  my $v1 = lc shift;
  my $v2 = lc shift;

  if ($v1 eq $v2) {
    #print "$v1 ? $v2\n";
    return 0;
  } elsif ($v1 gt $v2) {
    return 1;
  } else {
    return -1;
  };
};

sub checkFixLength {
  my $self = shift;
  my $value = shift;

  if (defined($self->{LENGTH})) {
    if (length($value)>$self->{LENGTH}) {
      if ($_D || $self->{_D}) {
	carp("$self\->checkFixLength() truncated value to $self->{LENGTH} length");
      };
      return substr($value, 0, $self->{LENGTH});
    };
  };

  return $value;
};

sub setModifiedFlag {
  my $self = shift;

  $self->{MODIFIED} = 1;
};

sub getModifiedFlag {
  my $self = shift;

  return $self->{MODIFIED};
};

sub clearModifiedFlag {
  my $self = shift;

  $self->{MODIFIED} = undef;
};

sub description {
  my $self = shift;

  return $self->{DESC};
};

sub oid {
  my $self = shift;

  return $self->{OID};
};

sub equality {
  my $self = shift;

  return $self->{EQUALITY};
};

sub syntax {
  my $self = shift;

  return $self->{SYNTAX};
};

sub substr {
  my $self = shift;

  return $self->{SUBSTR};
};

sub ordering {
  my $self = shift;

  return $self->{ORDERING};
};

sub usage {
  my $self = shift;

  return $self->{USAGE};
};

sub length {
  my $self = shift;

  return $self->{LENGTH};
};

sub isSingleValue {
  my $self = shift;

  return $self->{SINGLEVALUE};
};

sub isReadOnly {
  my $self = shift;

  return $self->{READONLY};
};

sub name {
  my $self = shift;

  return $self->{NAME};
};

sub className {
  my $self = shift;

  my $name = ref($self);
  $name =~ s/.*:://;

  return $name;
};

1;
