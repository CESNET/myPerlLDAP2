#!/usr/bin/perl -w

use lib qw(. ..);

use strict;
use Mozilla::OpenLDAP::Conn;
use Mozilla::OpenLDAP::API qw(LDAP_PORT LDAPS_PORT LDAP_SCOPE_BASE);

use vars qw($VERSION);
$VERSION = "0.0.1";

my $match_OID       = qw /^(\S+)\s+NAME/;
my $match_NAME      = qw /NAME\s+\'([\w\-]+)\'/;
my $match_MNAMES    = qw /NAME\s+\(\s*([\w\s\'\-]+)\s*\)/;
my $match_EQUALITY  = qw /EQUALITY\s+(\w+)/;
my $match_SYNTAX    = qw /SYNTAX\s+[\']*([\d\.\}\{]+)[\']*/;
my $match_SUP       = qw /SUP\s+(\w+)/;
my $match_DESC      = qw /DESC\s+\'(.*?)\'/;
my $match_SUBSTR    = qw /SUBSTR\s+(\w+)/;
my $match_ORDERING  = qw /ORDERING\s+(\w+)/;
my $match_USAGE     = qw /USAGE\s+(\w+)/;
my $match_SIGNLEV   = qw /SINGLE-VALUE/;
my $match_READONLY  = qw /NO-USER-MODIFICATION/;

my $superclasses = {
		    '1.3.6.1.4.1.1466.115.121.1.3'   => '_AttributeTypeDescription',
		    '1.3.6.1.4.1.1466.115.121.1.4'   => '_Audio',
		    '1.3.6.1.4.1.1466.115.121.1.5'   => '_Binary',
		    '1.3.6.1.4.1.1466.115.121.1.6'   => '_BinString',
		    '1.3.6.1.4.1.1466.115.121.1.8'   => '_Certificate',
		    '1.3.6.1.4.1.1466.115.121.1.9'   => '_CertificateList',
		    '1.3.6.1.4.1.1466.115.121.1.10'  => '_CertificatePair',
		    '1.3.6.1.4.1.1466.115.121.1.12'  => '_DN',
		    '1.3.6.1.4.1.1466.115.121.1.13'  => '_DataQualitySyntax',
		    '1.3.6.1.4.1.1466.115.121.1.14'  => '_DeliveryMethod',
		    '1.3.6.1.4.1.1466.115.121.1.15'  => '_DirectoryString',
		    '1.3.6.1.4.1.1466.115.121.1.16'  => '_DITContentRuleDescription',
		    '1.3.6.1.4.1.1466.115.121.1.17'  => '_DITStructureRuleDescription',
		    '1.3.6.1.4.1.1466.115.121.1.19'  => '_DSAQualitySyntax',
		    '1.3.6.1.4.1.1466.115.121.1.21'  => '_EnhancedGuide',
		    '1.3.6.1.4.1.1466.115.121.1.22'  => '_FacsimileTelephoneNumber',
		    '1.3.6.1.4.1.1466.115.121.1.23'  => '_Fax',
		    '1.3.6.1.4.1.1466.115.121.1.24'  => '_GeneralizedTime',
		    '1.3.6.1.4.1.1466.115.121.1.25'  => '_Guide',
		    '1.3.6.1.4.1.1466.115.121.1.26'  => '_IA5String',
		    '1.3.6.1.4.1.1466.115.121.1.27'  => '_Integer',
		    '1.3.6.1.4.1.1466.115.121.1.28'  => '_JPEG',
		    '1.3.6.1.4.1.1466.115.121.1.30'  => '_MatchingRuleDescription',
		    '1.3.6.1.4.1.1466.115.121.1.31'  => '_MatchingRuleUseDescription',
		    '1.3.6.1.4.1.1466.115.121.1.34'  => '_NameAndOptionalUID',
		    '1.3.6.1.4.1.1466.115.121.1.35'  => '_NameFormDescription',
		    '1.3.6.1.4.1.1466.115.121.1.36'  => '_NumericString',
		    '1.3.6.1.4.1.1466.115.121.1.37'  => '_ObjectClassDescription',
		    '1.3.6.1.4.1.1466.115.121.1.38'  => '_OID',
		    '1.3.6.1.4.1.1466.115.121.1.39'  => '_OtherMailbox',
		    '1.3.6.1.4.1.1466.115.121.1.40'  => '_OctetString',
		    '1.3.6.1.4.1.1466.115.121.1.41'  => '_PostalAddress',
		    '1.3.6.1.4.1.1466.115.121.1.42'  => '_ProtocolInformation',
		    '1.3.6.1.4.1.1466.115.121.1.43'  => '_PresentationAddress',
		    '1.3.6.1.4.1.1466.115.121.1.44'  => '_ProtocolInformation',
		    '1.3.6.1.4.1.1466.115.121.1.49'  => '_SupportedAlgorithm',
		    '1.3.6.1.4.1.1466.115.121.1.50'  => '_TelephoneNumber',
		    '1.3.6.1.4.1.1466.115.121.1.51'  => '_TeletexTerminalIdentifier',
		    '1.3.6.1.4.1.1466.115.121.1.52'  => '_TeletexNumber',
		    '1.3.6.1.4.1.1466.115.121.1.53'  => '_UTCTime',
		    '1.3.6.1.4.1.1466.115.121.1.54'  => '_LDAPSyntaxDescription',
		   };

sub parseAttributeType {
  my ($attr) = @_;

  my %attr;
  $attr{'origAttr'} = $attr;

  # Delete first "(" and last ")"
  $attr =~ s/^\( *//;
  $attr =~ s/ *\)$//;

  # OpenLDAP server doesn't report OID if it isn't in numerical form, Netscape
  # LDAP server does, so as OID I take first nonspace characters I found till
  # 'NAME' string ...
  if ($attr =~ s/$match_OID/NAME/o) {
    $attr{'oid'} = $1;
  };

  if ($attr =~ s/$match_NAME//o) {
    my @names = ($1);
    $attr{'name'} = \@names;
  };

  if ($attr =~ s/$match_MNAMES//o) {
    my $names = $1;
    $names =~ s/\'//go;
    my @names = split(/ /, $names);
    $attr{'name'} = \@names;
  };

  if ($attr =~ s/$match_EQUALITY//o) {
    $attr{'equality'} = $1;
  };

  if ($attr =~ s/$match_SYNTAX//o) {
    $attr{'syntax'} = $1;
  };

  if ($attr =~ s/$match_SUP//o) {
    $attr{'sup'} = $1;
  };

  if ($attr =~ s/$match_DESC//o) {
    $attr{'desc'} = $1;
  };

  if ($attr =~ s/$match_SUBSTR//o) {
    $attr{'substr'} = $1;
  };

  if ($attr =~ s/$match_ORDERING//o) {
    $attr{'ordering'} = $1;
  };

  if ($attr =~ s/$match_USAGE//o) {
    $attr{'usage'} = $1;
  };

  if ($attr =~ s/$match_SIGNLEV//o) {
    $attr{'singleValue'} = 1;
  };

  if ($attr =~ s/$match_READONLY//o) {
    $attr{'readOnly'} = 1;
  };

  $attr =~ s/ *//go;
  if ($attr ne "") {
    warn "Unmatched: \"$attr\" original: \"".$attr{'origAttr'}."\"\n";
  };

  if (!defined($attr{'oid'})) {
    $attr{'oid'}=${$attr{'name'}}[0].'-oid';
  };

  return(\%attr);
};

sub printAttributeHash {
  my ($attr) = @_;
  my ($ret) = "";

  if (defined($attr->{'name'})) {
    $ret .= "NAME=".join(', ', @{$attr->{'name'}})."\n";
  } else {
    $ret .= "NAME=??? ".$attr->{'origAttr'}."\n";
  };

  $ret .= "  OID=".$attr->{'oid'}."\n" if (defined($attr->{'oid'}));
  $ret .= "  EQUALITY=".$attr->{'equality'}."\n" if (defined($attr->{'equality'}));
  $ret .= "  SYNTAX=".$attr->{'syntax'}."\n" if (defined($attr->{'syntax'}));
  $ret .= "  SUP=".$attr->{'sup'}."\n" if (defined($attr->{'sup'}));
  $ret .= "  DESC=".$attr->{'desc'}."\n" if (defined($attr->{'desc'}));
  $ret .= "  SUBSTR=".$attr->{'substr'}."\n" if (defined($attr->{'substr'}));
  $ret .= "  ORDERING=".$attr->{'ordering'}."\n" if (defined($attr->{'ordering'}));
  $ret .= "  USAGE=".$attr->{'usage'}."\n" if (defined($attr->{'usage'}));
  $ret .= "  SINGLE-VALUE\n" if (defined($attr->{'singleValue'}));
  $ret .= "  READ-ONLY\n" if (defined($attr->{'readOnly'}));

  return($ret);
};

my $originalDir = `pwd`; chomp($originalDir);
my $autoClassesPath = ".auto";
my $attrClassesPath = "myPerlLDAP/Attribute";

sub attributeHash2Class {
  my($attr) = @_;

  my($syntax, $length) = (undef, undef);
  my($superclass);

  if (defined($attr->{syntax})) {
    if ($attr->{syntax} =~ /(.*?)\{(.*?)\}/) {
      $syntax = $1;
      $length = $2;
    } else {
      $syntax = $attr->{syntax};
    };
  };

  if ((!defined($syntax)) and (!defined($attr->{sup}))) {
    warn "Undefined syntax and superclass for object $attr->{oid} skiping\n";
    #printAttributeHash($attr);
    return 0;
  };

  if ((defined($syntax)) and (!defined($superclasses->{$syntax}))) {
    warn "Unknown syntax '$syntax' for object $attr->{oid} skiping\n";
    #printAttributeHash($attr);
    return 0;
  };

  if (defined($syntax)) {
    $superclass="myPerlLDAP::Attribute::$superclasses->{$syntax}";
  } elsif ((!defined($syntax)) or ()) {
    $superclass="myPerlLDAP::Attribute::$attr->{sup}";
  } else {
    warn "This should never happen. Coding error! Please report conditions.";
    return 0;
  };

  my ($name, $classDefiniton, $classHash);
  for $name (@{$attr->{name}}) {
    $name = lc $name;
    my $init_code = "";

    my (@k, @v);
    do { push @k, "'OID'";
	 push @v, "'$attr->{oid}'"} if (defined($attr->{'oid'}));
    do { push @k, "'EQUALITY'";
	 push @v, "'$attr->{equality}'"} if (defined($attr->{'equality'}));
    do { push @k, "'SYNTAX'";
	 push @v, "'$syntax'"} if (defined($syntax));
    do { push @k, "'DESC'";
	 push @v, "'$attr->{desc}'"} if (defined($attr->{'desc'}));
    do { push @k, "'SUBSTR'";
	 push @v, "'$attr->{substr}'"} if (defined($attr->{'substr'}));
    do { push @k, "'ORDERING'";
	 push @v, "'$attr->{ordering}'"} if (defined($attr->{'ordering'}));
    do { push @k, "'USAGE'";
	 push @v, "'$attr->{usage}'"} if (defined($attr->{'usage'}));
    do { push @k, "'LENGTH'";
	 push @v, $length} if (defined($length));
    do { push @k, "'SINGLEVALUE'";
	 push @v, 1} if (defined($attr->{'singleValue'}));
    do { push @k, "'READONLY'";
	 push @v, 1} if (defined($attr->{'readOnly'}));
    $init_code = '  @{$self}{'.join(",\n           ", @k)."} =
    {".join(",\n     ", @v)."};\n";

    $classDefiniton = "# $attr->{origAttr}";
    $classHash = "# ".join("\n# ", split(/\n/, printAttributeHash($attr)));

    open(CLASS, ">$originalDir/$attrClassesPath/$autoClassesPath/$name\.pm") or die "Can't open file $attrClassesPath/$autoClassesPath/$name\.pm for writing";
    print CLASS <<EOF
#!/usr/bin/perl -w

# This class was automaticaly created by buildClasses.pl, from definiton:
#
$classDefiniton
#
# which was parsed to internal buildClasses.pl's hash on this way:
#
$classHash
#
# buildClasses.pl is part of the myPerlLDAP package developed 
# at CESNET (http://www.cesnet.cz/) by Jan Tomasek <jan\@tomasek.cz>.

package myPerlLDAP::Attribute::$name;

use strict;
use $superclass;
use vars qw(\$VERSION \@ISA);

\$VERSION = "$VERSION";

\@ISA = ('$superclass');

sub init {
  my \$self = shift;

  \$self->SUPER::init();

$init_code
};
EOF
;
    close(CLASS);
    symlink("$autoClassesPath/$name\.pm", "$name\.pm") or die "Can't create link $attrClassesPath/$autoClassesPath/$name\.pm->$attrClassesPath/$name\.pm: $!";
  };

  return 1;
};

# Return 1 if both are same, DESC isn't compared
sub compareAttributeHash {
  my ($a1, $a2) = @_;
  my ($elem);

  if ((scalar keys %{$a1}) != (scalar keys %{$a2})) {
    warn "Attribute hashs (".join(', ', @{$a1->{name}}).") and (".join(', ', @{$a2->{name}}).") have difrent ements counts";
    return 0;
  };

  foreach $elem (keys %{$a1}) {
    if ($elem =~ /^name$/io) {
    } elsif ($elem =~ /^desc$/io) {
    } elsif ($elem =~ /^origAttr$/io) {
    } else {
      if ($a1->{$elem} ne $a2->{$elem}) {
	warn join(', ', @{$a1->{name}})."->{$elem}=$a1->{$elem} != ".join(', ', @{$a1->{name}})."->{$elem}=$a1->{$elem}";
	return 0;
      };
    };
  };

  return 1;
};

#my $LDAPServerHost = "tady.ten.cz";
#my $LDAPServerHost = "nms.ctt.cz";
my $LDAPServerHost = "localhost";
my $LDAPServerPort = LDAP_PORT;

my $conn = new Mozilla::OpenLDAP::Conn({"host"   => $LDAPServerHost,
					"port"   => $LDAPServerPort,
					"certdb" => 1} )
  or die "Can't connect to the LDAP server ($LDAPServerHost:$LDAPServerPort)";

# Findout where schema is stored
my $entry = $conn->search(' ',
			  LDAP_SCOPE_BASE,
			  '(objectClass=*)',
			  0,
			  ('subSchemaSubEntry'))
  or die "Can't locate place where schema is stored";

my $subSchemaSubEntry  = $entry->{'subSchemaSubEntry'}[0];

$entry = $conn->search($subSchemaSubEntry,
		       LDAP_SCOPE_BASE,
		       '(objectclass=*)',
		       0,
		       ("attributeTypes", "ldapSyntaxes"))
  or die "Can't read schema";

# clean old classes, prepare place for new
mkdir("$attrClassesPath/$autoClassesPath");
opendir(DIR, $attrClassesPath) or die "Can't opendir $attrClassesPath: $!";
my @files =  grep { (!/^\.*$/) and (-l "$attrClassesPath/$_")} readdir(DIR);
closedir(DIR);
unlink map { "$attrClassesPath/$_" } @files;
# change working dir
chdir($attrClassesPath) or die "Can't chdir to $attrClassesPath: $!";

my ($attr, $syn, $a, %attrList);
while ($entry) {
  foreach $attr (@{$entry->{'attributetypes'}}) {
    $a = parseAttributeType($attr);

    # Add this attribute to atribute hash
    if (defined($attrList{$a->{'oid'}})) {
      if (compareAttributeHash($attrList{$a->{'oid'}}, $a)) {
	push @{$attrList{$a->{'oid'}}->{'name'}}, @{$a->{'name'}};
      } else {
	print "--- DUPLICATED UNMATCHED OID --- \n";
	print printAttributeHash($attrList{$a->{'oid'}});
	print " \n";
	print printAttributeHash($a);
	print "--- DUPLICATED UNMATCHED OID --- \n\n";
      };
    } else {
      $attrList{$a->{'oid'}} = $a;
    };
  };

  #foreach $syn (@{$entry->{'ldapSyntaxes'}}) {
  #  print "$syn\n";
  #};

  $entry = $conn->nextEntry();
};

my $oid;
foreach $oid (keys %attrList) {
  attributeHash2Class($attrList{$oid});
};
