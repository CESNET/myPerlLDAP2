#!/usr/bin/perl -w

package myPerlLDAP::entry;

use strict;
use Carp;

use myPerlLDAP::attribute;

use vars qw($VERSION $_D $AUTOLOAD %fields);

$VERSION = "0.5.0";

# TODO:
# - constructor for completly NEW entry (not loaded from ldap)
# - renaming atributes
# - change DN


# Debug levels:
#  1 ... warnings about nasty class usage (trying set value of read-only attr ...)
# 10 ... excution of some methods
$_D = 1;

%fields = (
	   dn          => undef,
	   debug       => $_D,
	   attrData    => {},
	   attrOrder   => [],
	   attrChanges => [],
	   attrInit    => {},
	  );

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  if ($_D >= 10) {
    carp("$class created");
  };

  my $self = bless {_permitted_fields => \%fields, %fields}, $class;
  foreach my $field (keys %fields) {
    if (ref($fields{$field}) eq "HASH") {
      my %hash;
      $self->{$field} = \%hash;
    };
    if (ref($fields{$field}) eq "ARRAY") {
      my @array;
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

sub clearModifiedFlags {
  my $self = shift;

  $self->attrChanges([]);
  $self->attrInit({});

  my $attr;
  foreach $attr ($self->attributesList) {
    $self->attr($attr)->clearModifiedFlag;
    $self->attrInit->{$attr}=1;
  };
};

sub attributesList {
  my $self = shift;

  return @{$self->attrOrder};
};

sub attr {
  my $self = shift;
  my $attr = lc shift;

  return $self->attrData->{$attr};
};

sub LDIF {
  my $self = shift;

  my ($attr, $value);
  my (@out);

  # TODO: dn, objectclasses, potom ten prvni z dn (RDN)
  push @out, ("dn: ".$self->dn);
  foreach $attr ($self->attributesList) {
    if (defined($self->attr($attr)) and ($self->attr($attr)->count)) {
      foreach $value (@{$self->attr($attr)->get}) {
	push @out, ("$attr: $value");
      };
    }; # else: Attribute which have no value doesn't exists.
   };

  return \@out;
};

sub LDIFString {
  my $self = shift;

  return join("\n", @{$self->LDIF})."\n";
};

sub remove {
  my $self = shift;
  my $attr = lc shift;

  if (!defined($attr)) {
    if ($_D || $self->debug) {
      carp("$self\->remove called without attr name");
    };
    return undef;
  };

  if ($self->attr($attr)) {
    delete $self->attrData->{$attr};
    push @{$self->attrChanges}, ("-$attr");
    my @changes = grep(!/^$attr$/, @{$self->attrOrder});
    $self->attrOrder(\@changes);
    return 1;
  } else {
    if ($_D || $self->debug) {
      carp("$self\->remove attempt to remove non existing attribute=\"$attr\"");
    };
    return undef;
  };
};

sub add {
  my $self = shift;
  my $attr = shift;

  if (!defined($attr)) {
    if ($_D || $self->debug) {
      carp("$self\->add called without attribute");
    };
    return undef;
  };

  if (defined($self->attr($attr->name))) {
    if ($_D || $self->debug) {
      carp("$self\->addAsValues attempt to add attribute which exists");
    };
    return undef;
  };

  push @{$self->attrOrder}, ($attr->name);
  push @{$self->attrChanges}, ("+".$attr->name);
  $self->attrData->{$attr->name}=$attr;
  # object will be added to ATTR_ADDED so is useless to be marked as modified
  # because it will be writen to an LDAP db completely again
  $self->attrData->{$attr->name}->clearModifiedFlag;
  return $self->attrData->{$attr->name};
};

sub addAsValues {
  my $self = shift;
  my $attr = shift;

  if (!defined($attr) or (!defined($_[0]))) {
    if ($_D || $self->debug) {
      carp("$self\->addAsValues called without attribute name or value(s)");
    };
    return undef;
  };

  if (defined($self->attr($attr))) {
    if ($_D || $self->debug) {
      carp("$self\->addAsValues attempt to add attribute which exists");
    };
    return undef;
  };

  # Create and add new attribute
  my $new_attr = new myPerlLDAP::attribute($attr);
  my $RO = $new_attr->readOnly;
  $new_attr->readOnly=0 if $RO;

  if ($new_attr) {
    if ($new_attr->set(@_)) {
      $new_attr->readOnly=1 if $RO;
      return $self->add($new_attr);
    };
  };

  $new_attr->readOnly=1 if $RO;

  return;
};

sub makeAddRecord {
  my $self = shift;
  my %rec;

  my $attr;
  foreach $attr ($self->attributesList) {
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

#    print "delete: $attr<BR>";

    $rec{$attr}->{rb}=[];
  };

  foreach $attr (keys %add) {
    die "This should never happen" if (defined($rec{$attr}));

#    print "add: $attr<BR>";

    $rec{$attr}->{rb}=$self->attr($attr)->get;
  };

  foreach $attr (keys %replace) {
    die "This should never happen" if (defined($rec{$attr}));

#    print "replace: $attr<BR>";

    $rec{$attr}->{rb}=$self->attr($attr)->get;
  };

  foreach $attr ($self->attributesList) {
    if (($self->attr($attr)->getModifiedFlag()) and (!defined($rec{$attr}))) {

#      print "rec: $attr<BR>";
      # TODO: This is nasty. I'm replacing whole attribute, but now
      # I don't have much time ... to do better implementation I will
      # need modify myPerlLDAP::attribute to be able produce modificaion
      # record for this.
      $rec{$attr}->{rb}=$self->attr($attr)->get;
    };# else -> attribute was added as new and after that it was modified
      # I not process it here because it is being added as new attr ...
  };

  return \%rec;
};

sub XML {
  my $self = shift;
  my @ret;
  my $attr;

  push @ret, "<dsml:entry dn=\"".$self->dn."\">";
  foreach $attr ($self->attributesList) {
    push @ret, map { "  $_"} @{$self->attr($attr)->XML};
  };
  push @ret, "</dsml:entry>";

  return \@ret;
};

sub XMLString {
  my $self = shift;
  my $ident = shift;

  $ident = "" unless $ident;

  return join("\n", map { "$ident$_" } @{$self->XML})."\n";
};

1;
