#!/usr/bin/perl -w

package myPerlLDAP::attribute;

use strict;

use Carp;
use vars qw($VERSION  $_D $AUTOLOAD %fields);

$VERSION = "0.5.0";

# Debug levels:
#  1 ... warnings about nasty class usage
# 10 ... excution of some methods
$_D = 1;

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
           debug         => $_D,
           modified      => undef,
           values        => undef,
           name          => undef,
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

  if (eval "require myPerlLDAP::attribute::$requestedClass" ) {
    $class = "myPerlLDAP::attribute::$requestedClass";
  } else {
    if ($_D) {
      carp("Can't load module \"myPerlLDAP::attribute::$requestedClass\" attribute \"$requestedClass\" created as \"$class\"");
    };
  };

  my $self = bless {_permitted_fields => \%fields, %fields}, $class;

  $self->name($requestedClass);
  $self->init;

  if (($_D >= 10) || ($self->debug >= 10)) {
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

  if (($_D >= 10) || ($self->debug >= 10)) {
    carp("$self initiated");
  };
};


sub DESTROY {
  my $self = shift;

  if (($_D >= 10) || ($self->debug >= 10)) {
    carp("$self destroyed");
  };
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

sub count {
  my $self = shift;

  if (!defined($self->{VALUES})) {
    return 0;
  };

  return scalar @{$self->{VALUES}};
};

sub set {
  my $self = shift;

  if ($self->readOnly) {
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
    if (($self->singleValue) and (scalar @values)) {
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

  if ($self->readOnly) {
    # This READ ONLY attribute we can't change it
    if ($_D || $self->debug) {
      carp("Attempt to change read-only object $self");
    };
    return undef;
  };

  if (!(scalar @_)) {
    # No value suplied
    if ($_D || $self->debug) {
      carp("$self\->add() called without any value");
    };
    return undef;
  };

  if (($self->singleValue) and (scalar @{$self->{VALUES}})) {
    # This attribute is only single value and value is set
    if ($_D || $self->debug) {
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
      if ($_D || $self->debug) {
	carp("$self\->add() same value=\"$value\" passed to attribute");
      };
    } else {
      push @values, $self->checkFixLength($value);
    };
    if (($self->singleValue) and (scalar @values)) {
      # This attribute is only single value so we take only first
      if ((@$values > 1) and ($_D || $self->debug)) {
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

  if ($self->readOnly) {
    # This READ ONLY attribute we can't change it
    if ($_D || $self->debug) {
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
    if ($_D || $self->debug) {
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

  if (defined($self->length)) {
    if (length($value)>$self->length) {
      if ($_D || $self->debug) {
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

sub className {
  my $self = shift;

  my $name = ref($self);
  $name =~ s/.*:://;

  return $name;
};

sub getXML {
  my $self = shift;
  my @ret;
  my $value;

  if ($self->name eq 'objectclass') {
    push @ret, '<dsml:objectclass>';
    foreach $value (@{$self->get()}) {
      push @ret, "  <dsml:oc-value>$value</dsml:oc-value>";
    };
    push @ret, '</dsml:objectclass>';
  } else {
    push @ret, "<dsml:attr name=\"".$self->name."\">";
    foreach $value (@{$self->get()}) {
      push @ret, "  <dsml:value>$value</dsml:value>";
    };
    push @ret, "</dsml:attr name=\"".$self->name."\">";
  };

  return \@ret;
};

1;
