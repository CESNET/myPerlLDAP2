#!/usr/bin/perl -w

package myPerlLDAP::attribute;

use strict;

use Carp;
use vars qw($VERSION  $_D $AUTOLOAD %fields);

$VERSION = "0.5.2";

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
           name          => undef,
	   owner         => undef,
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

  my $self = bless {_permitted_fields => \%FIELDS, %fields}, $class;

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
  # This is fastest way how to code this function ;-)
  $self->{VALUES} = undef;
  return $self->add(@_);
};

# If possible adds new value(s), accepts two args:
#  1. array ref or scalar - REQUIRED
#  2. OPTIONAL type of values scalar only
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

  my (@values); # Here I put values which will be finally added to
                # internal classes structures.
  my ($values); # This will be array ref of value(s) passed by user
                # to this method
  # Examine if first arg is one value (scalar) or multiple values (array ref)
  if (ref($_[0]) eq "ARRAY") {
    $values = shift;
  } else {
    my @v;
    $v[0] = shift;
    $values = \@v;
  };
  # Subtype of values is optional
  my $type = shift;

  if (($self->singleValue) and (scalar @{$self->get($type)})) {
    # This attribute is only single value and value is set
    if ($_D || $self->debug) {
      carp("$self\->add() another value passed to single-value attribute");
    };
    return undef;
  };

  foreach my $value (@$values) {
    if ($self->has($value,$type)) {
      if ($_D || $self->debug) {
	carp("$self\->add() same value=\"$value\" passed to attribute");
      };
    } else {
      my @valElem = ($self->checkFixLength($value), $type);
      push @values, \@valElem;
    };
  };
 ENDFOREACH:

  if (($self->singleValue) and (scalar @values)) {
    # This attribute is only single value so we take only first
    if (((scalar @$values) > 2) and ($_D || $self->debug)) {
      carp("more than one value passed to singe-value attribute $self");
    };
    # @values = splice(@values, 2);
    my $val = $values[0];
    @values = ($val);
  };

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
      my $j = 0;
      while ($j < @{$self->{VALUES}}) {
	$v2 = $self->{VALUES}->[$j];
	my @v1 = ($v1,$t1);
        if ($self->compareValues(\@v1, $v2)) {
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

  $self->setModifiedFlag() if ($count);

  if ($count != (scalar @$values)) {
    if ($_D || $self->debug) {
      my $COUNT = scalar @$values;
      carp("$self\->remove-d only $count of expectected $COUNT values");
    };
  };

  return $count;
}; # remove

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
    if ($_D || $self->debug) {
      carp("$self\->has() called without any value");
    };
    return undef;
  };

  return $count;
}; # has

sub get {
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
}; # get

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

sub makeModificationRecord {
  my $self = shift;
  my $mode = shift;
  my %res;

  foreach my $type (@{$self->types}) {
    my $TYPE = "";
    $TYPE = ";$type" if ($type);
    if ($res{$self->name."$TYPE"}->{$mode}) {
    } else {
      $res{$self->name."$TYPE"}->{$mode} = $self->get($type);
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
    foreach $value (@{$self->get}) {
      push @ret, "  <dsml:oc-value>$value</dsml:oc-value>";
    };
    push @ret, '</dsml:objectclass>';
  } else {
    my $attrArgs ='';
    $attrArgs = $self->xmlAttributeArgs if ($self->xmlAttributeArgs);
    push @ret, "<dsml:attr name=\"".$self->name."\"$attrArgs>";
    foreach my $type (@{$self->types}) {
      foreach $value (@{$self->get($type)}) {
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
    foreach $value (@{$self->get($type)}) {
      my $TYPE = "";
      $TYPE = ";$type" if ($type);
      push @ret, $self->name."$TYPE: $value";
    };
  };

  return \@ret;
};

1;
