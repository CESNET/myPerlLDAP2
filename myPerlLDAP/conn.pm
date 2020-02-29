#!/usr/bin/perl -w
#$Id$

package myPerlLDAP::conn;

use strict;

use Net::LDAPS;
use Net::LDAP;
use Net::LDAP::Constant qw(LDAP_SUCCESS LDAP_COMPARE_TRUE);
use Net::LDAP::Control;
use Net::LDAP::Control::ProxyAuth;
use myPerlLDAP::abstract;
use myPerlLDAP::utils qw /:all/;
use myPerlLDAP::entry;
use myPerlLDAP::searchResult;
use myPerlLDAP::aci;
use Sys::Syslog;
use Data::Dumper;

use vars qw($SYSLOG $VERSION @ISA %fields);

@ISA = ("myPerlLDAP::abstract");

$VERSION = "1.90";

$SYSLOG = 0;

%fields = (
    debug => 1,
    host => undef,
    port => undef,
    bindDN => undef,
    bindPasswd => undef,
    proxyDN => undef,
    certDB => undef,
    ld => undef, #TODO SEMIK zlikvidovat
    ldRes => undef,
    dn => undef,
    aciCTRLSuported => undef,
    aciCTRL => undef,
    proxyCTRL => undef,
    retry => 0,
    delay => 1,
    ldap => undef,
    ldap_last => undef,
    
    );

#############################################################################
# Creator, create and initialize a new LDAP object ("connection"). We support
# either providing all parameters as a hash array, or as individual
# arguments.
#
# It will not initalize connection to LDAP server!
#
# Based on code from perLDAP-1.4
#
# TODO: For SSL use an betther flag than stupid certdb ... OpenLDAP client
# isn't now able to work with certs I think.

sub construct {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $self = bless $class->SUPER::new(@_), $class;

  foreach my $element (keys %fields) {
    $self->{_permitted_fields}->{$element} = $fields{$element};
  };
  @{$self}{keys %fields} = values %fields;

  if (ref $_[$[] eq "HASH") {
    my ($hash);

    $hash = $_[$[];
    $self->host($hash->{"host"}) if defined($hash->{"host"});
    $self->port($hash->{"port"}) if defined($hash->{"port"});
    $self->bindDN($hash->{"bind"}) if defined($hash->{"bind"});
    $self->bindPasswd($hash->{"pswd"}) if defined($hash->{"pswd"});
    $self->certDB($hash->{"certdb"}) if defined($hash->{"certdb"});
    $self->retry($hash->{"retry"}) if defined($hash->{"retry"});
    $self->delay($hash->{"delay"}) if defined($hash->{"delay"});
    $self->proxyDN($hash->{"proxydn"}) if defined($hash->{"proxydn"});
  } else {
    my ($host, $port, $binddn, $bindpasswd, $certdb, $authmeth) = @_;

    $self->host($host);
    $self->port($port);
    $self->bindDN($binddn);
    $self->bindPasswd($bindpasswd);
    $self->certDB($certdb);
  };

  $self->bindDN("") unless defined($self->bindDN);
  $self->bindPasswd("") unless defined($self->bindPasswd);

  if (!defined($self->port) || ($self->port eq "")) {
    $self->port((($self->certDB ne "") ? LDAPS_PORT : LDAP_PORT));
  }

  return $self;
};

#############################################################################
# Creator, create and initialize a new LDAP object ("connection"). We support
# either providing all parameters as a hash array, or as individual
# arguments.
#
# It will initalize connection to LDAP server!
#
sub new {
  my $self = construct(@_);

  return unless $self;
  return unless $self->init();
  return $self;
}; # new -------------------------------------------------------------------


#############################################################################
# Destructor, makes sure we close any open LDAP connections.
#
# Without any changes copied from perLDAP-1.4
#
sub DESTROY {
  my ($self) = shift;

  return unless defined($self->ld);

  if (!defined($self->ld)) {
    $self->close();
    $self->ld(undef);
  };
}; # DESTROY ----------------------------------------------------------------

#############################################################################
# New method taken from Net::LDAP - it releases internal structures of
# last request
# 
sub abandon {
  my ($self) = shift;

  if (defined($self->ldap_last)) {
      $self->ldap_last->abandon;
      $self->ldap_last(undef);
  };
  return 1;
}; 

#############################################################################
# Initialize a normal connection. This seems silly, why not just merge
# this back into the creator method (new)...
#
# Folowing code is based on perlLDAP-1.4 was modified by Milan (I think)
# for OpenLDAP, and some other minor changes were done by me ... it will
# not be merged back to constructor I like this way ;-)
sub init {
  my ($self) = shift;

  my $ldap;

  if (defined($self->certDB) && ($self->certDB ne "")) {
    $ldap = Net::LDAPS->new($self->host, port => $self->port);
  } else {
    $ldap = Net::LDAP->new($self->host, port => $self->port);
  };
  return unless $ldap;

  $self->ldap($ldap);
  my $ret = $self->simpleAuth($self->bindDN, $self->bindPasswd);

  #bez ohledu na vysledek zapomeneme heslo
  $self->bindPasswd(undef);

  return $ret;
} # init --------------------------------------------------------------------

sub initACI {
    my $self = shift;
    # Check if server is supporting ACI control if so, prepare one
    # for automatic ACI retrieval (nebo jak se to pise)
    
    my $rootDSE = $self->read("", 'supportedControl');
    my $supportedControl = $rootDSE->getValues('supportedControl');

    $self->{aciCTRLSuported} = grep { $_ eq '1.3.6.1.4.1.42.2.27.9.5.2'} @{$supportedControl};

    return $self->{aciCTRLSuported};
};

#############################################################################
# Create a new, empty, Entry object.
#
# Personaly I don't se any reason for this function, but I'm will leave it
# here for users migrating from Mozilla:perLDAP or Mozilla:OpenLDAP
#
sub newEntry {

  return new myPerlLDAP::entry;
} # newEntry ----------------------------------------------------------------

#############################################################################
# Checks if a string is a properly formed LDAP URL.
#
# Without any changes copied from perLDAP-1.4
#
sub isURL {
  my ($self, $url) = @_;

  return ldap_is_ldap_url($url);
} # isURL -------------------------------------------------------------------

#############################################################################
# Return the Error code from the last LDAP api function call. The last two
# optional arguments are pointers to strings, and will be set to the
# match string and extra error string if appropriate.
#
# Based on code of function getErrorCode from perLDAP-1.4
#
sub error {
  my ($self, $match, $msg) = @_;
  my ($ret);

  return LDAP_SUCCESS unless defined($self->ldap_last);
  return $self->ldap_last->{resultCode};
}; # getErrorCode -----------------------------------------------------------

#############################################################################
# Return the Error string from the last LDAP api function call.
#
# Without any change copied from perLDAP-1.4
#
sub errorMessage {
  my ($self) = shift;
  my ($err);

  # Net::LDAP vraci v pripade OK stavu v promene errorMessage prazdny
  # string.
  return '' unless defined($self->ldap_last);
  return $self->ldap_last->{errorMessage};
} # getErrorString ----------------------------------------------------------

#############################################################################
# Normal LDAP search. 
#
sub search {
  my ($self, $basedn, $scope, $filter, $attrsonly, @attrs) = @_;
  my ($resv);
  my ($res) = \$resv;

  $self->abandon;
  $filter = "(objectclass=*)" if ($filter =~ /^ALL$/i);

#  if (ldap_is_ldap_url($filter)) {
#    if (! ldap_url_search_s($self->ld, $filter, $attrsonly, $res)) {
#      my $sRes = new myPerlLDAP::searchResults($self->ld, $res);
#      return $sRes;
#    };
#      return undef;
#  } else {

  my @controls;
  if (defined($self->aciCTRL)) {
      push @controls, $self->aciCTRL;
      push @attrs, 'aclRights'
  };      
  if (defined($self->proxyCTRL)) {
      push @controls, $self->proxyCTRL;
  };

  my %search_params = ( base => $basedn,
			scope => $scope,
			filter => $filter);
  $search_params{attrs} = \@attrs if (@attrs);
  $search_params{control} = \@controls if (@controls);

  my $mesg = $self->ldap->search(%search_params);
  if ($mesg->code == LDAP_SUCCESS) {
      my $sRes = new myPerlLDAP::searchResult($mesg, $self);
      $sRes->owner($self);
      return $sRes;
  };

  # Semik: Nevim jestli bych nemel zaregistrovat vysledek hledani i
  # kdyz vse dopadne dobre. Obavam se ale ze mivam paralelne
  # rozzpracovanych nekolik hledani. Takze o likvidaci se bude muset
  # postarat objekt searchResult.
  $self->ldap_last($mesg);
  return
} # search ------------------------------------------------------------------

#############################################################################
# Read one entry identified by it's DN, list of required attrs is
# also supported.
#
sub read {
  my ($self, $dn, @attrs) = @_;

  if (@attrs and (scalar(@attrs)==1)) {
      @attrs = @{$attrs[0]} if (ref($attrs[0]) eq 'ARRAY');
  };

  my @controls;
  if (defined($self->aciCTRL)) {
      push @controls, $self->aciCTRL;
      push @attrs, 'aclRights'
  };      
  if (defined($self->proxyCTRL)) {
      push @controls, $self->proxyCTRL;
  };
  
  my %search_params = ( base => $dn,
			scope => LDAP_SCOPE_BASE,
			filter => '(objectclass=*)');
  $search_params{attrs} = \@attrs if (@attrs);
  $search_params{control} = \@controls if (@controls);

  my $mesg = $self->ldap->search(%search_params);
  $self->ldap_last($mesg);
  if ($mesg->code == LDAP_SUCCESS) {
      my $nentry = $mesg->entry(0);

      my $entry = new myPerlLDAP::entry;
      $entry->initFromNetLDAP($nentry);
      $entry->owner($self);

      return $entry;
  };

  return;
  
  # if (!ldap_search_s($self->ld, $dn, LDAP_SCOPE_BASE, '(objectclass=*)',
  # 		     defined(\@attrs) ? \@attrs : 0,
  # 		     0,
  # 		     defined($res) ? $res : 0)) {
  #   my $sRes = new myPerlLDAP::searchResult($self->ld, $res, $self);
  #   if ($sRes) {
  #     my $entry = $sRes->nextEntry;
  #     return $entry;
  #   };
  # };

  return undef;
}; # read -------------------------------------------------------------------

#############################################################################
# URL search, optimized for LDAP URL searches.
#
# Without any change copied from perLDAP-1.4
#
#sub searchURL {
#  my ($self, $url, $attrsonly) = @_;
#  my ($resv, $entry);
#  my ($res) = \$resv;

#  if (defined($self->ldRes)) {
#    ldap_msgfree($self->ldRes);
#    $self->ldRes(undef);
#  };

#  if (!ldap_url_search_s($self->ld, $url,
#			 defined($attrsonly) ? $attrsonly : 0,
#			 defined($res) ? $res : 0)) {
#    $self->ldRes = $res;
#    $self->{ldfe} = 1;
#    $entry = $self->nextEntry();
#  };

#  return $entry;
#}; # searchURL -------------------------------------------------------------

#############################################################################
# Browse an LDAP entry, very much like the regular search, except we set
# some defaults (like scope=BASE, filter=(objectclass=*) and so on). Note
# that this method does not support the attributesOnly flag.
#
# Based on perlLDAP-1.4 code (I little reduced code)
#
sub browse {
  my ($self, $basedn, @attrs) = @_;

  return undef;

  #TODO SEMIK
  
#  return  $self->search($basedn, LDAP_SCOPE_BASE, "(objectclass=*)",
#			0, @attrs);
}; # browse -----------------------------------------------------------------

#############################################################################
# Compare an attribute value against a DN in the server (without having to
# do a search first).
#
# Without any change copied from perLDAP-1.4
#
sub compare {
    my ($self, $dn, $attr, $value) = @_;

    my $mesg = $self->ldap->compare($dn,
				    attr => $attr,
				    value => $value);

    return ($mesg->{resultCode} == LDAP_COMPARE_TRUE);
}; # compare ----------------------------------------------------------------

#############################################################################
# Close the connection to the LDAP server.
#
# With minor change copied from perLDAP-1.4
#
sub close {
  my $self = shift;
  my $ret = LDAP_SUCCESS; # Originaly was here that assignment $ret = 1 ...
                          # it never can't work; Actualy this is useles ...

  if (defined($self->ldap)) {
      my $mesg = $self->ldap->unbind;
      $self->ldap_last($mesg);
      return (($mesg->code == LDAP_SUCCESS) ? 1 : undef);
  };
  $self->ldap_last(undef);
  $self->ldap(undef);

  return
}; # close ------------------------------------------------------------------

#############################################################################
# Delete an object. An Entry ...
#
sub delete {
  my $self = shift;
  my $id = shift;
  my $dn = $id;

  if (ref($id) eq 'myLDAP::entry') {
    $dn = $id->dn;
  } else {
    $self->dn($dn) unless (defined($dn) && ($dn ne ""));
  };

  my $mesg = $self->ldap->delete($dn);
  $self->ldap_last($mesg);
  
  _syslog("DEL(".$mesg->code.")", $self->bindDN, $dn) if ($SYSLOG);
  return 1 if ($mesg->code == LDAP_SUCCESS);

}; # delete -----------------------------------------------------------------

#############################################################################
# Add an object. This fuction expect as argument myPerlLDAP::entry,
# it will not accept HASH like original function from perlLDAP!
#
# Based on perlLDAP, heavy modified for my new Entry ... most of code was
# deleted, functionality is now in Entry::makeAddRecord
#
sub add {
  my ($self, $entry) = @_;

  return unless $entry;

  my $rec = $entry->makeAddRecord;

  my %params = (attrs => [%{$rec->{add}}]);

  if (defined($self->proxyCTRL)) {
      $params{control} =  [ $self->proxyCTRL ];
  };
 
  my $mesg = $self->ldap->add($entry->dn,
			      %params);
  $self->ldap_last($mesg);

  $self->_modRecord2syslog("ADD(".$mesg->code.")", $entry, secureModRecord($rec));

   if ($mesg->code == LDAP_SUCCESS) {
    $entry->clearModifiedFlags;
    return 1;
  } else {
    return undef;
  };
}; # add --------------------------------------------------------------------

#############################################################################
# Modify the RDN, and update the entry accordingly. Note that the last
# two arguments (DN and "delete") are optional. The last (optional) argument
# is a flag, which if set to TRUE (the default), will cause the corresponding
# attribute value to be removed from the entry.
#
# Without any change copied from perLDAP-1.4
#
sub modifyRDN {
  my ($self, $rdn, $dn, $del) = ($_[$[], $_[$[ + 1], $_[$[ + 2], $_[$[ + 3]);
  my (@vals);
  my ($ret) = 1;

  $del = 1 unless (defined($del) && ($del ne ""));
  $self->dn($dn) unless (defined($dn) && ($dn ne ""));

  @vals = ldap_explode_dn($dn, 0);
  if (lc($vals[$[]) ne lc($rdn)) {
    $ret = ldap_modrdn2_s($self->ld, $dn, $rdn, $del);
    if ($ret == LDAP_SUCCESS) {
      shift(@vals);
      unshift(@vals, ($rdn));
      $self->dn(join(@vals));
    };
  };

  return (($ret == LDAP_SUCCESS) ? 1 : 0);
}; # modifyRDN --------------------------------------------------------------

sub secureModRecord {
  my $rec = shift;

  $rec->{userpassword} = { x => ['values removed from debug for security reasons']} if (defined($rec->{userpassword}));
  $rec->{tacuserpassword} = { x => ['values removed from debug for security reasons']} if (defined($rec->{tacuserpassword}));
  $rec->{radiuspassword} = { x => ['values removed from debug for security reasons'] } if (defined($rec->{radiuspassword}));

  return $rec;
};

#############################################################################
# Update an object.
#
# Inspired by perlLDAP-1.4 code - most of code was deleted, functionality
# is now in Entry::makeModificationRecord. Each book about OOP says:
#
#    "Nerver let user or other class using your class touch it's
#     internal structures."
#

sub _syslog {
  sub escape {
    my $line = shift;

    $line =~ s,\:,\/\:,g;

    return $line;
  };

  openlog('caas', 'cons,pid', 'local8');
  syslog('info', join(":", map {escape($_)} @_));
  closelog();
};

sub _modRecord2syslog {
  my $self = shift;
  my $id = shift;
  my $entry = shift;
  my $rec = shift;

  foreach my $attr (sort keys %{$rec}) {
      next if ($attr eq 'control');
    foreach my $mode (sort keys %{$rec->{$attr}}) {
      my $counter=0;
      foreach my $value (@{$rec->{$attr}->{$mode}}) {
	_syslog($id, $self->bindDN, $entry->dn, $attr, $mode, $value)
	  if ($SYSLOG);
	$counter++;
      };
      _syslog($id, $self->bindDN, $entry->dn, $attr, $mode)
	if (($counter==0) and ($SYSLOG>1));
    };
  };
};

sub update {
  my ($self, $entry) = @_;

  my $rec = $entry->makeModificationRecord;

  my @controls;
  if (defined($self->proxyCTRL)) {
      $rec->{control} = [ $self->proxyCTRL ];
  };

  my $mesg = $self->ldap->modify($entry->dn,
				 %{$rec});

  $self->ldap_last($mesg);

  $self->_modRecord2syslog("MOD(".$mesg->{resultCode}.")", $entry, secureModRecord($rec));

  if ($mesg->{resultCode} == LDAP_SUCCESS) {
      $entry->clearModifiedFlags;
      return 1;
  };
  return undef;


  die Dumper($rec);

  
  my $ret = ldap_modify_s($self->ld, $entry->dn, $rec);

  $self->_modRecord2syslog("MOD($ret)", $entry, secureModRecord($rec));

  if ($ret == LDAP_SUCCESS) {
    $entry->clearModifiedFlags;
    return 1;
  } else {
    print STDERR "Failed to update entry \"".$entry->dn."\" due \"".$self->errorMessage."\".\n";
    print STDERR "Modification record: ".Dumper(secureModRecord($rec));
    return undef;
  };
}; # update -----------------------------------------------------------------

# SEMIK REMOVE: Nemyslim ze to nekde pouzivam
# #############################################################################
# # Set the rebind procedure. We also provide a neat default rebind procedure,
# # which takes three arguments (DN, password, and the auth method). This is an
# # extension to the LDAP SDK, which I think should be there. It was also
# # needed to get this to work on Win/NT...
# #
# # Without any change copied from perLDAP-1.4 ... I've no idea what is this
# #
# sub setRebindProc {
#   my ($self, $proc) = @_;

#   # Should we try to reinitialize the connection?
#   die "No LDAP connection" unless defined($self->ld);

#   ldap_set_rebind_proc($self->ld, $proc);
# }; # setRebindProc ----------------------------------------------------------

# sub setDefaultRebindProc {
#   my ($self, $dn, $pswd, $auth) = @_;

#   $auth = LDAP_AUTH_SIMPLE unless defined($auth);
#   die "No LDAP connection"
#     unless defined($self->ld);

#   ldap_set_default_rebind_proc($self->ld, $dn, $pswd, $auth);
# } # setDefaultRebindProc ----------------------------------------------------

# TODO: Tahle fce je docel podobna fci init - kod je duplikovan chce
# to init naucit pouzivat tuhle.
#############################################################################
# Do a simple authentication, so that we can rebind as another user.
#
sub simpleAuth {
  my ($self, $dn, $pswd) = @_;
  my ($ret);

  $self->abandon;

  my $count = 0;
  do {
    sleep($self->delay) if ($count++ > 0);

    if (($dn) and ($pswd)) {
	$ret = $self->ldap->bind($dn, password => $pswd);
    } else {
	$ret = $self->ldap->bind;
    };
  } while (($ret->code != LDAP_SUCCESS) and ($count < $self->retry));
  $self->ldap_last($ret);

  if ($ret->code == LDAP_SUCCESS) {
      $self->bindDN($dn);
      $self->bindPasswd($pswd);
  };

  $self->{aciCTRLSuported} = undef;
  if (($ret->code == LDAP_SUCCESS) and ($pswd)) {
      $self->initACI;

      if ($self->proxyDN) {
	  my $auth = Net::LDAP::Control::ProxyAuth->new(authzID => 'dn: '.$self->proxyDN);
	  $self->proxyCTRL($auth);
      };
  };

  return (($ret->code == LDAP_SUCCESS) ? 1 : undef);

  # if (defined($self->certDB) && ($self->certDB ne "")) {
  #     $ldap = Net::LDAPS->new($self->host, port => $self->port);
  # } else {
  #     $ldap = Net::LDAP->new($self->host, port => $self->port);
  # };
  # return unless $ldap;
  
  # $self->abandon;
  # $ret = $ldap->bind($dn,
  # 		     password => $pswd);
  # $self->ldap($ldap);

  # $self->bindDN($dn);
  # $self->bindPasswd($pswd);

  # $self->{aciCTRLSuported} = undef;
  # if (($ret->code == LDAP_SUCCESS) and (defined($pswd))) {
  #   return $self->initACI;
  # } else {
  #   return (($ret->code == LDAP_SUCCESS) ? 1 : undef);
  # };

  # die "myPerlLDAP::conn: We can't reach this point";
  # return (($ret->code == LDAP_SUCCESS) ? 1 : 0);
}; # simpleAuth -------------------------------------------------------------


#############################################################################
# Retrieve ACI info from server if posible
#
# docs https://access.redhat.com/documentation/en-us/red_hat_directory_server/9.0/html/administration_guide/viewing_the_acis_for_an_entry-get_effective_rights_control
sub readACI {
  my $self = shift;
  my $dn = shift;
  my @attrs = @_;


  if ($self->aciCTRLSuported) {
      my $bind_dn = $self->bindDN;
      $bind_dn = $self->proxyDN if ($self->proxyDN);
      my $ctrl = Net::LDAP::Control->new(critical=> 1,
					 type => '1.3.6.1.4.1.42.2.27.9.5.2',
					 value => 'dn: '.$bind_dn,
	  );

      my @controls;
      push @controls, $ctrl;
      if (defined($self->proxyCTRL)) {
	  push @controls, $self->proxyCTRL;
      };
      
      my $mesg = $self->ldap->search(base => $dn,
				     scope => 'base',
				     filter => '(objectClass=*)',
				     control => \@controls,
				     attrs => [ 'aclrights', @attrs ], # entry and attributes
	  );
      $self->ldap_last($mesg);

      return undef unless ($mesg->code == LDAP_SUCCESS);
      $self->aciCTRL($ctrl);
      
      my $aci = new myPerlLDAP::aci($mesg->entry(0));
      $aci->owner($self);
      return $aci;
  } else {
      my %hash;
      $hash{'aclrights;entrylevel'} = ['add:0,delete:0,read:1,write:0,proxy:0'];
      foreach my $attr (@attrs) {
	  $hash{"aclrights;attributelevel;$attr"} = ['search:1,read:1,compare:1,write:0,selfwrite_add:0,selfwrite_delete:0,proxy:0'];
      };

      my $aci = new myPerlLDAP::aci;
      $aci->initFromHash(\%hash);

      return $aci
  };
};

# SEMIK 8. 3. 2018: nemyslim ze by se to nekde pouzivalo
# sub initACICTRL {
#   my $self = shift;
#   my @attrs = @_;

#   $self->freeACICTRL;

#   if ($self->aciCTRLSuported) {
#     my $ret = ldap_create_rights_control($self->ld,
# 					 "",#as actualy loged user
# 					 \@attrs,#list of attrs we are interested in
# 					 1,#critical? YES!
# 					 $self->{aciCTRL});
#     # error code is accesible via $self->ld
#     return undef unless ($ret==LDAP_SUCCESS);
#   } else {
#     return undef;
#   };
# };

# sub freeACICTRL {
#   my $self = shift;

#   # Release old ACICTRL if any was defined
#   if (defined($self->aciCTRL)) {
#     ldap_control_free($self->aciCTRL); $self->aciCTRL(undef);
#   };
# };

#############################################################################
# Mandatory TRUE return value.
#
1;
__END__

=head1 NAME

myPerLDAP::Conn - LDAP server connection object

=head1 SYNOPSIS

  use strict;
  use Mozilla::OpenLDAP::API qw(LDAP_PORT LDAPS_PORT LDAP_SCOPE_SUBTREE);
  use myPerlLDAP::Conn;

  my $LDAPServerHost = "localhost";
  my $LDAPServerPort = LDAP_PORT;

  my $conn = new myPerlLDAP::Conn({"host"   => $LDAPServerHost,
				   "port"   => $LDAPServerPort})
    or die "Can't connect to $LDAPServerHost:$LDAPServerPort";

  my @attr = ('cn', 'sn', 'givenname');
  my $res = $conn->search('ou=People,o=test', LDAP_SCOPE_SUBTREE,
	  		  '(uid=*)', 0, @attr)
    or do {
      $conn->printError();
      die "Can't search"
    };


  my $entry = $res->nextEntry;
  while ($entry) {
    print $entry->LDIFString;
    print "\n";

    $entry = $res->nextEntry;
  };

=head1 SEE ALSO

L<myPerlLDAP::searchResult>, L<myPerlLDAP::entry>, L<myPerlLDAP::attribute>

=cut
