#!/usr/bin/perl -w

package myPerlLDAP::Entry;

use strict;
use Carp;

use myPerlLDAP::Attribute;

use vars qw($VERSION);

$VERSION = "0.0.1";

# TODO:
# - constructor for completly NEW entry (not loaded from ldap)
# - renaming atributes
# - change DN


# Debug levels:
#  1 ... warnings about nasty class usage (trying set value of read-only attr ...)
# 10 ... excution of some methods
my $_D = 1;

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};


  $self->{_D} = $_D;

  if (($_D >= 10) || ($self->{_D} >= 10)) {
    carp("$class created");
  };

  bless($self, $class);
  $self->init(@_);

  return $self;
};

sub init {
  my $self = shift;
  my $args = shift;

  $self->{DN} = undef;
  $self->{ATTR} = {};
  $self->{ATTR_ORDER} = [];
  $self->clearModifiedFlags;

  if (($_D >= 10) || ($self->{_D} >= 10)) {
    carp("$self initiated");
  };
};

sub clearModifiedFlags {
  my $self = shift;

  $self->{ATTR_CHANGES} = [];
  $self->{ATTR_INIT} = {};

  my $attr;
  foreach $attr ($self->getAttributesList) {
    $self->attr($attr)->clearModifiedFlag;
    $self->{ATTR_INIT}->{$attr}=1;
  };
};

sub DESTROY {
  my $self = shift;

  if (($_D >= 10) || ($self->{_D} >= 10)) {
    carp("$self destroyed");
  };
};

sub getAttributesList {
  my $self = shift;

  return @{$self->{ATTR_ORDER}};
};

sub attr {
  my $self = shift;
  my $attr = lc shift;

  return $self->{ATTR}->{$attr};
};

sub getLDIF {
  my $self = shift;

  my ($attr, $value);
  my (@out);

  # TODO: dn, objectclasses, potom ten prvni z dn (RDN)
  push @out, ("dn: ".$self->getDN());
  foreach $attr ($self->getAttributesList) {
    if (defined($self->attr($attr)) and ($self->attr($attr)->count)) {
      foreach $value (@{$self->attr($attr)->get}) {
	push @out, ("$attr: $value");
      };
    }; # else: Attribute which have no value doesn't exists.
   };

  return \@out;
};

sub getLDIF_String {
  my $self = shift;

  return join("\n", @{$self->getLDIF})."\n";
};


sub getDN {
  my $self = shift;

  return $self->{DN};
};

# TODO: How about renaming?
sub setDN {
  my $self = shift;

  $self->{DN}=shift;
};

sub remove {
  my $self = shift;
  my $attr = lc shift;

  if (!defined($attr)) {
    if ($_D || $self->{_D}) {
      carp("$self\->remove called without attr name");
    };
    return undef;
  };

  if ($self->attr($attr)) {
    delete $self->{ATTR}->{$attr};
    push @{$self->{ATTR_CHANGES}}, ("-$attr");
    my @changes = grep(!/^$attr$/, @{$self->{ATTR_ORDER}});
    $self->{ATTR_ORDER} = \@changes;
    return 1;
  } else {
    if ($_D || $self->{_D}) {
      carp("$self\->remove attempt to remove non existing attribute=\"$attr\"");
    };
    return undef;
  };
};

sub add {
  my $self = shift;
  my $attr = shift;

  if (!defined($attr)) {
    if ($_D || $self->{_D}) {
      carp("$self\->add called without attribute");
    };
    return undef;
  };

  if (defined($self->attr($attr->name))) {
    if ($_D || $self->{_D}) {
      carp("$self\->addAsValues attempt to add attribute which exists");
    };
    return undef;
  };

  push @{$self->{ATTR_ORDER}}, ($attr->name);
  push @{$self->{ATTR_CHANGES}}, ("+".$attr->name);
  $self->{ATTR}->{$attr->name}=$attr;
  # object will be added to ATTR_ADDED so is useless to be marked as modified
  # because it will be writen to an LDAP db completely again
  $self->{ATTR}->{$attr->name}->clearModifiedFlag;
  return $self->{ATTR}->{$attr->name};
};

sub addAsValues {
  my $self = shift;
  my $attr = shift;

  if (!defined($attr) or (!defined($_[0]))) {
    if ($_D || $self->{_D}) {
      carp("$self\->addAsValues called without attribute name or value(s)");
    };
    return undef;
  };

  if (defined($self->attr($attr))) {
    if ($_D || $self->{_D}) {
      carp("$self\->addAsValues attempt to add attribute which exists");
    };
    return undef;
  };

  # Create and add new attribute
  my $new_attr = new myPerlLDAP::Attribute($attr);
                                  # TODO: Findout an OOP correct way
  my $RO = $new_attr->{READONLY}; # This is dirty, but simplest way how to
  $new_attr->{READONLY}=0 if $RO; # temporarly disable RO checks ... it is
                                  # required for initial values setting
  if ($new_attr) {
    if ($new_attr->set(@_)) {
      $new_attr->{READONLY}=1 if $RO;
      return $self->add($new_attr);
    };
  };

  $new_attr->{READONLY}=1 if $RO;

  return;
};

sub makeAddRecord {
  my $self = shift;
  my %rec;

  my $attr;
  foreach $attr ($self->getAttributesList) {
    if (defined($self->attr($attr)) and ($self->attr($attr)->count)) {
      $rec{$attr}->{ab}=$self->attr($attr)->get;
    }; # else: Attribute which have no value doesn't exists.
  };

  return \%rec;
};

sub makeModificationRecord {
  my $self = shift;

  my %rec;
  my %delete;
  my %replace;
  my %add;

  my ($attr, $x);
  foreach $x (@{$self->{ATTR_CHANGES}}) {

    if ($x =~ /^\-(.*)$/) { # delete
      $attr = $1;
      if ($self->{ATTR_INIT}->{$attr}) {
	$delete{$attr}=1;
	delete $add{$attr} if (exists($add{$attr}));
	delete $replace{$attr} if (exists($replace{$attr}));
      }; # else -> attribute isn't in LDAP database it was added and deleted
         # someone who is using myPerlLDAP::Entry, we can't pass this to
         # server othervise all requests will fail
    };

    if ($x =~ /^\+(.+)$/) { # add
      $attr = $1;

      if ($self->{ATTR_INIT}->{$attr}) {
	# we can't add attribute which is in LDAP database, we have to overwrite
	# it. This can happen if user first deletes attribute and then add it again.
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

  foreach $attr (keys %add) {
    die "This should never happen" if (defined($rec{$attr}));

    $rec{$attr}->{ab}=$self->attr($attr)->get;
  };

  foreach $attr (keys %replace) {
    die "This should never happen" if (defined($rec{$attr}));

    $rec{$attr}->{rb}=$self->attr($attr)->get;
  };

  foreach $attr ($self->getAttributesList) {
    if (!defined($rec{$attr})) {
      # TODO: This is nasty. I'm replacing whole attribute, but now
      # I don't have much time ... to do better implementation I will
      # need modify myPerlLDAP::Attribute to be able produce modificaion
      # record for this.
      $rec{$attr}->{rb}=$self->attr($attr)->get;
    };# else -> attribute was added as new and after that it was modified
      # I not process it here because it is being added as new attr ...
  };

  return \%rec;
};

1;
