#!/usr/bin/perl -w

package myPerlLDAP::searchResult;

#use perlOpenLDAP::API 1.4 qw(ldap_first_entry ldap_next_entry ldap_msgfree
#			     ldap_get_dn ldap_first_attribute
#			     ldap_next_attribute ldap_get_values_len
#			     ldap_ber_free ldap_count_entries);

use myPerlLDAP::attribute;
use myPerlLDAP::entry;
use myPerlLDAP::aci;
use Data::Dumper;
use Carp;

use strict;
use vars qw($_D @ISA %fields);

@ISA = ("myPerlLDAP::abstract");

%fields = (
	   debug  => 1,
	   sEntr  => undef,
	   sEntrI => 0,
	   owner  => undef,
	  );

# TODO:
#   - firstNetry

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = bless $class->SUPER::new(@_), $class;
  my %FIELDS = (%{$self->{_permitted_fields}}, %fields);
  $self->{_permitted_fields} = \%FIELDS;
  $self->debug($_D);

  return unless $self->init(@_);

  return $self;
};

sub init {
    my $self = shift;
    my $res = shift;
    my $conn = shift;
    
    if (defined($res)) {
	$self->{ldres}=$res;
	$self->owner($conn);
	$self->{ldfe}=1;
	$self->{sEntrI} = 0;
	
	return $self;
    } else {
	carp("$self->init requires res arg");
	return undef;
    };
};

#############################################################################
# Add new attribute to entry if necessary and add values to it. Only for
# internal use by myPerlLDAP::searchResults::nextEntry
#
sub addValues2Entry {
  my $self = shift;
  my $entry = shift;
  my $lcattr = shift;
  my $values = shift;

  $lcattr =~ /(^[^;]+)(;|)(.*?)$/;
  my $attrName = undef; $attrName = $1 if ($1 ne '');
  my $valueType = undef; $valueType = $3 if ($3 ne '');

  my $eattr = $entry->attr($attrName);
  if (defined($eattr)) {
    $eattr->addValues($values, $valueType);
  } else {
    $entry->addValues($attrName, $values, $valueType);
  };

  return $eattr;
};

#############################################################################
# Get an entry from the search, either the first entry, or the next entry,
# depending on the call order.
#
# Based on perlLDAP-1.4 code, I did heavy modification to be usefull
# with my new Entry. Originaly it was part of the Conn class, but
# I don't like way how multiple searches on same ld are done in perlLDAP-1.4
# so I created this class and moved some code here.
#
sub nextEntry {
    my $self = shift;

    if (defined($self->sEntr) and defined($self->sEntr->{$self->sEntrI})) {
	# entry uz jsme jednou prevzali od podrazeneho objektu, takze
	# vracime nasi hodnotu z kese
	my $entry = $self->sEntr->{$self->{sEntrI}++};
	return $entry;
    } elsif ($self->sEntrI < $self->{ldres}->count) {
	my $nentry = $self->{ldres}->entry($self->sEntrI);

	my $entry = new myPerlLDAP::entry();
	$entry->initFromNetLDAP($nentry);
	$entry->owner($self->owner);

	if ($self->owner->aciCTRL) {
	    my $aci = new myPerlLDAP::aci($nentry);
	    if ($aci) {
		$aci->owner($self);
		$entry->aci($aci);
	    };
	};
	
	$self->{sEntr}->{$self->sEntrI} = $entry;
	$self->{sEntrI}++;

	# SEMIK TODO: ACI!!!

	return $entry;
    } else {
	return
    };
   

  # if (defined($self->sEntr)) {
  #   my $entry = $self->sEntr->{$self->{sEntrI}++};
  #   return $entry;
  # } else {
  #   my (%entry, @vals);
  #   my ($attr, $lcattr, $ldentry, $berv, $dn, $count);
  #   my ($ber) = \$berv;

  #   my $entry = new myPerlLDAP::entry();
  #   $entry->owner($self->owner);

  #   if ($self->{"ldfe"} == 1) {
  #     return unless defined($self->{"ldres"});

  #     $self->{"ldfe"} = 0;
  #     $ldentry = ldap_first_entry($self->{"ld"}, $self->{"ldres"});
  #     $self->{"ldentry"} = $ldentry;
  #   } else {
  #     return unless defined($self->{"ldentry"});

  #     $ldentry = ldap_next_entry($self->{"ld"}, $self->{"ldentry"});
  #     $self->{"ldentry"} = $ldentry;
  #   };

  #   if (! $ldentry) {
  #     #if (defined($self->{"ldres"})) {
  #     #  ldap_msgfree($self->{"ldres"});
  #     #  undef $self->{"ldres"};
  #     #}
  #     return undef;
  #   };

  #   $dn = ldap_get_dn($self->{"ld"}, $self->{"ldentry"});
  #   $entry->dn($dn);

  #   $attr = ldap_first_attribute($self->{"ld"}, $self->{"ldentry"}, $ber);
  #   $entry->clearModifiedFlags;
  #   return $entry unless $attr;

  #   my %aclRights;
  #   $count = 1;
  #   while ($attr) {
  #     $lcattr = lc $attr;
  #     my @vals = ldap_get_values_len($self->{"ld"}, $self->{"ldentry"}, $attr);
  #     if ($lcattr =~ /^aclrights/) {
  # 	$aclRights{$lcattr} = \@vals;
  #     } else {
  # 	$self->addValues2Entry($entry, $lcattr, \@vals);
  #     };

  #     $attr = ldap_next_attribute($self->{"ld"},
  # 				  $self->{"ldentry"}, $ber);
  #     $count++;
  #   };
  #   ldap_ber_free($ber, 0) if $ber;

  #   if (%aclRights) {
  #     my $aci = new myPerlLDAP::aci;
  #     $aci->initFromHash(\%aclRights);
  #     $entry->aci($aci);
  #   } else {
  #     # Ten samy kod co je u myPerlLDAP::conn chtelo by to udelat nejak lip.
  #     my %hash;
  #     $hash{'aclrights;entrylevel'} = ['add:0,delete:0,read:1,write:0,proxy:0'];
  #     foreach my $attr (@{$entry->attrList}) {
  # 	$hash{"aclrights;attributelevel;$attr"} = ['search:1,read:1,compare:1,write:0,selfwrite_add:0,selfwrite_delete:0,proxy:0'];
  #     };

  #     my $aci = new myPerlLDAP::aci;
  #     $aci->initFromHash(\%hash);
  #     $entry->aci($aci);
  #   };

  #   $entry->clearModifiedFlags;
  #   return $entry;
  # };
};

# Allows using nextEntry from beginning
sub reset {
  my $self = shift;

  if (defined($self->sEntr)) {
    $self->sEntrI(0);
  } else {
    $self->{"ldfe"} = 1;
  };
};

# Return count of returned entries
sub count {
    my $self = shift;

    # 16. 3. 2018 tohle je pekne stupidni, kdyz se zavola tahle metoda
    # behem prvniho iterovani skrz pole tak to vrati picovinu. Hash
    # sEntr vznikne po prvnim volani nextEntry.
    if (defined($self->sEntr)) {
	my $count = keys %{$self->sEntr};
	return $count;
    };

    return $self->{ldres}->count;
};

sub cmpEntryNode {
  my $aCount = scalar @{$a->{sortKey}};
  my $bCount = scalar @{$b->{sortKey}};

  if ($aCount != $bCount) {
    warn "sortKey count missmatch sorting by dn";
    return ($a->{entry}->dn cmp $b->{entry}->dn);
  };

  for(my $i=0; $i<$aCount; $i++) {
    my $cmp = $a->{sortKey}->[$i] cmp $b->{sortKey}->[$i];
    return $cmp if ($cmp != 0);
  };

  return 0;
};

sub sort {
  my $self = shift;
  my @sortBy = @_;

  return undef unless @sortBy;

  my %entries;
  my %sortedEntries;
  my $counter=0;

  $self->reset;
  my $entry = $self->nextEntry;
  while ($entry) {
    my $key = $entry->dn;
    my @sortKeyValues;
    foreach my $sortKey (@sortBy) {
      my $values = $entry->getValues($sortKey,'lang-en');
      my $valuesCount = (scalar @{$values});
      if ($valuesCount == 0) {
	$values = $entry->getValues($sortKey);
	$valuesCount = (scalar @{$values});
      };
      if ($valuesCount == 0) {
	# There is no value, but we were required to sort by... so empty string
	# is IMHO best choice
	push @sortKeyValues, '';
      } else {
	# How about multiple values?? Taking just first!
	push @sortKeyValues, $values->[0];
      };
    };
    $entries{$key} = {sortKey => \@sortKeyValues,
		      entry => $entry};
    $entry = $self->nextEntry;
  };

  foreach my $entryNode (sort cmpEntryNode values %entries) {
      $sortedEntries{$counter++} = $entryNode->{entry};
  };

  $self->sEntr(\%sortedEntries);
  $self->sEntrI(0);

  return 1;
};

sub cacheLocaly {
  my $self = shift;

  my $entry;
  my $counter = 0;
  my %localEntries;
  $self->reset;

  while ($entry = $self->nextEntry) {
    $localEntries{$counter++} = $entry;
  };

  $self->sEntr(\%localEntries);
  $self->sEntrI(0);

  return 1;
};

sub removeLocaly {
  my $self = shift;
  my @remove = @_;

  $self->cacheLocaly unless (defined($self->sEntr));
  $self->reset;

  my %localEntries = %{$self->sEntr};
  my %newLocalEntries;

  my @r;
  my $counter = 0;
  my $count = $self->count;
  for(my $i=0; $i<$count; $i++) {
    my $dn = $localEntries{$i}->dn;
    if (grep {$_ eq $dn} @remove) {
    } else {
      $newLocalEntries{$counter++} = $localEntries{$i};
    };
  };

  $self->sEntr(\%newLocalEntries);
  $self->sEntrI(0);

  return 1;
};

sub owner {
  my $self = shift;

  if (@_) {
    return $self->{OWNER} = shift;
  } else {
    return $self->{OWNER};
  };
};

1;
