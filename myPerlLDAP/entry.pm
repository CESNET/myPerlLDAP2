#!/usr/bin/perl -w

package myPerlLDAP::entry;

use strict;
use Carp;

use myPerlLDAP::attribute;
use myPerlLDAP::utils qw(quote4XML quote4HTTP);

use vars qw($VERSION $_D $AUTOLOAD %fields);

$VERSION = "0.5.1";

# TODO:
# - constructor for completly NEW entry (not loaded from ldap)
# - renaming atributes
# - change DN


# Debug levels:
#  1 ... warnings about nasty class usage
# 10 ... excution of some methods
$_D = 1;

%fields = (
	   dn          => undef,
	   debug       => $_D,
	   attrData    => {},
	   attrOrder   => [],
	   attrChanges => [],
	   attrInit    => {},
	   attrMap     => {},
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
      push @out, @{$self->attr($attr)->LDIF};
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
  my $type = shift;

  my $class;

  if (defined($self->attrMap->{$attr})) {
    $class = $self->attrMap->{$attr};
  } else {
    $class = myPerlLDAP::attribute::classNamePrefix().$attr;
    if (eval "require $class" ) {
    } else {
      if (($myPerlLDAP::attribute::_D) and ($attr ne "")) {
	carp("Can't load module \"$class\" attribute \"$attr\" created as \"myPerlLDAP::attribute\"");
      };
      $class = 'myPerlLDAP::attribute';
    };
  };

  # Create and add new attribute
  my $new_attr = $class->new($attr);
  my $RO = $new_attr->readOnly;
  $new_attr->readOnly=0 if $RO;

  if ($new_attr) {
    if ($new_attr->set($values, $type)) {
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
      #$rec{$attr}->{ab}=$self->attr($attr)->get;
      %rec = (%rec, %{$self->attr($attr)->makeModificationRecord('ab')});
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

    #$rec{$attr}->{rb}=$self->attr($attr)->get;
    %rec = (%rec, %{$self->attr($attr)->makeModificationRecord('rb')});
  };

#  foreach $attr (keys %replace) {
#    die "This should never happen" if (defined($rec{$attr}));

#    $rec{$attr}->{rb}=$self->attr($attr)->get;
#  };

  foreach $attr ($self->attributesList) {
    if (($self->attr($attr)->getModifiedFlag()) and (!defined($rec{$attr}))) {
      # TODO: This is nasty. I'm replacing whole attribute, but now
      # I don't have much time ... to do better implementation I will
      # need modify myPerlLDAP::attribute to be able produce modificaion
      # record for this.
      #$rec{$attr}->{rb}=$self->attr($attr)->get;
      %rec = (%rec, %{$self->attr($attr)->makeModificationRecord('rb')});
    };# else -> attribute was added as new and after that it was modified
      # I not process it here because it is being added as new attr ...
  };

  return \%rec;
};

sub XML {
  my $self = shift;
  my @ret;
  my $attr;

#  warn quote4XML("1 2 3");

  push @ret, "<dsml:entry dn=\"".quote4XML($self->dn)."\" urldn=\"".quote4XML(quote4HTTP($self->dn))."\" xmlns:dsml=\"http://www.dsml.org/DSML\">";
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
