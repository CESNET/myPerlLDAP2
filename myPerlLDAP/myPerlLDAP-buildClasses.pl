#!/usr/bin/perl -w
#$Id$

# #############################################################################
# myPerlLDAP - object oriented interface for work with LDAP
# Copyright (C) 2001,02 by Jan Tomasek
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Library General Public License for more details.
#
# You should have received a copy of the GNU Library General Public
# License along with this library; if not, write to the Free
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
# #############################################################################

use lib qw(..);

use strict;
use myPerlLDAP::conn;
use myPerlLDAP::attribute;
use perlOpenLDAP::API qw(LDAP_PORT LDAP_SCOPE_BASE);

$myPerlLDAP::attribute::_D=0;

my %tree; # This is global variable =?> Am I dirty programmer? :))

my $LDAPServerHost = 'localhost';
my $LDAPServerPort = LDAP_PORT;
my $attrClassesPath = "/tmp/myPerlLDAP-ac";
my $autoClassesPath = "attribute";

my @files;

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
		    '1.3.6.1.4.1.1466.115.121.1.3'   => '_attributeTypeDescription',
		    '1.3.6.1.4.1.1466.115.121.1.4'   => '_audio',
		    '1.3.6.1.4.1.1466.115.121.1.5'   => '_binary',
		    '1.3.6.1.4.1.1466.115.121.1.6'   => '_binString',
		    '1.3.6.1.4.1.1466.115.121.1.8'   => '_certificate',
		    '1.3.6.1.4.1.1466.115.121.1.9'   => '_certificateList',
		    '1.3.6.1.4.1.1466.115.121.1.10'  => '_certificatePair',
		    '1.3.6.1.4.1.1466.115.121.1.12'  => '_DN',
		    '1.3.6.1.4.1.1466.115.121.1.13'  => '_dataQualitySyntax',
		    '1.3.6.1.4.1.1466.115.121.1.14'  => '_deliveryMethod',
		    '1.3.6.1.4.1.1466.115.121.1.15'  => '_directoryString',
		    '1.3.6.1.4.1.1466.115.121.1.16'  => '_DITContentRuleDescription',
		    '1.3.6.1.4.1.1466.115.121.1.17'  => '_DITStructureRuleDescription',
		    '1.3.6.1.4.1.1466.115.121.1.19'  => '_DSAQualitySyntax',
		    '1.3.6.1.4.1.1466.115.121.1.21'  => '_enhancedGuide',
		    '1.3.6.1.4.1.1466.115.121.1.22'  => '_facsimileTelephoneNumber',
		    '1.3.6.1.4.1.1466.115.121.1.23'  => '_fax',
		    '1.3.6.1.4.1.1466.115.121.1.24'  => '_generalizedTime',
		    '1.3.6.1.4.1.1466.115.121.1.25'  => '_guide',
		    '1.3.6.1.4.1.1466.115.121.1.26'  => '_IA5String',
		    '1.3.6.1.4.1.1466.115.121.1.27'  => '_integer',
		    '1.3.6.1.4.1.1466.115.121.1.28'  => '_JPEG',
		    '1.3.6.1.4.1.1466.115.121.1.30'  => '_matchingRuleDescription',
		    '1.3.6.1.4.1.1466.115.121.1.31'  => '_matchingRuleUseDescription',
		    '1.3.6.1.4.1.1466.115.121.1.34'  => '_nameAndOptionalUID',
		    '1.3.6.1.4.1.1466.115.121.1.35'  => '_nameFormDescription',
		    '1.3.6.1.4.1.1466.115.121.1.36'  => '_numericString',
		    '1.3.6.1.4.1.1466.115.121.1.37'  => '_objectClassDescription',
		    '1.3.6.1.4.1.1466.115.121.1.38'  => '_OID',
		    '1.3.6.1.4.1.1466.115.121.1.39'  => '_otherMailbox',
		    '1.3.6.1.4.1.1466.115.121.1.40'  => '_octetString',
		    '1.3.6.1.4.1.1466.115.121.1.41'  => '_postalAddress',
		    '1.3.6.1.4.1.1466.115.121.1.42'  => '_protocolInformation',
		    '1.3.6.1.4.1.1466.115.121.1.43'  => '_presentationAddress',
		    '1.3.6.1.4.1.1466.115.121.1.44'  => '_protocolInformation',
		    '1.3.6.1.4.1.1466.115.121.1.49'  => '_supportedAlgorithm',
		    '1.3.6.1.4.1.1466.115.121.1.50'  => '_telephoneNumber',
		    '1.3.6.1.4.1.1466.115.121.1.51'  => '_teletexTerminalIdentifier',
		    '1.3.6.1.4.1.1466.115.121.1.52'  => '_teletexNumber',
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
    $superclass="myPerlLDAP::attribute::$superclasses->{$syntax}";
  } elsif ((!defined($syntax)) or ()) {
    $superclass="myPerlLDAP::attribute::".lc($attr->{sup});
  } else {
    warn "This should never happen. Coding error! Please report conditions.";
    return 0;
  };

  my ($name, $classDefiniton, $classHash);
  for $name (@{$attr->{name}}) {
    $name = lc $name;
    my $init_code = "";

    my @f;
    push @f, "OID => '".$attr->{oid}."'" if (defined($attr->{'oid'}));
    push @f, "equality => '".$attr->{equality}."'" if (defined($attr->{'equality'}));
    push @f, "syntax => '$syntax'" if (defined($syntax));
    push @f, "description => '".$attr->{desc}."'" if (defined($attr->{'desc'}));
    push @f, "subStr => '".$attr->{substr}."'" if (defined($attr->{'substr'}));
    push @f, "ordering => '".$attr->{ordering}."'" if (defined($attr->{'ordering'}));
    push @f, "usage => '".$attr->{usage}."'" if (defined($attr->{'usage'}));
    push @f, "length => $length" if (defined($length));
    push @f, "singleValue => 1" if (defined($attr->{'singleValue'}));
    push @f, "readOnly => 1" if (defined($attr->{'readOnly'}));

    my $fields = "\%fields = (".join(",\n           ", @f).");";

    $classDefiniton = "# $attr->{origAttr}";
    $classHash = "# ".join("\n# ", split(/\n/, printAttributeHash($attr)));

    push @files, "$autoClassesPath/$name\.pm";
    open(CLASS, ">$attrClassesPath/$autoClassesPath/$name\.pm") or die "Can't open file $attrClassesPath/$autoClassesPath/$name\.pm for writing";
    print CLASS <<EOF
#!/usr/bin/perl -w

# This class was automaticaly created by myPerlLDAP-buildClasses.pl, 
# from definiton:
#
$classDefiniton
#
# which was parsed to internal buildClasses.pl's hash on this way:
#
$classHash
#
# buildClasses.pl is part of the myPerlLDAP package developed 
# at CESNET (http://www.cesnet.cz/) by Jan Tomasek <jan(at)tomasek.cz>.

package myPerlLDAP::attribute::$name;

use strict;
use $superclass;
use vars qw(\$VERSION \@ISA \%fields);

\$VERSION = '$VERSION';

\@ISA = ('$superclass');

$fields

sub new {
  my \$proto = shift;
  my \$class = ref(\$proto) || \$proto;
  my \$self = bless \$class->SUPER::new(\@_), \$class;

  foreach my \$element (keys \%fields) {
    \$self->{_permitted_fields}->{\$element} = \$fields{\$element};
  };
  \@{\$self}{keys \%fields} = values \%fields;

  return \$self;
};

1;

EOF
;
   close(CLASS);

   if (!defined($tree{$superclass})) {
     my @array;
     $tree{$superclass}=\@array;
   };
   $superclass =~ s/.*:://;
   push(@{$tree{$superclass}}, $name);
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

sub printClassTree {
  my $attr = shift;
  my $shift = shift;

  my $cattr;
  my $ret = "$shift$attr\n";
  if ($tree{$attr}){
    foreach $cattr (sort @{$tree{$attr}}) {
      $ret .= printClassTree($cattr, "$shift     ");
    };
  };
  return $ret;
};


sub readAnswer {
  my ($prompt,$default) = @_;
  print $prompt;
  print " [$default]: ";
  my $resp = <STDIN>;
  chomp($resp);
  $resp =~ /\S/ ? $resp : $default;
}

print "myPerlLDAP - attribute classes generator\n";
print "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n";
$LDAPServerHost = readAnswer("LDAP server hostname", $LDAPServerHost);
$LDAPServerPort = readAnswer("LDAP server port", $LDAPServerPort);
$attrClassesPath = readAnswer("Where do you want to write clases", $attrClassesPath);

mkdir("$attrClassesPath");
mkdir("$attrClassesPath/attribute");

my $conn = new myPerlLDAP::conn({"host"   => $LDAPServerHost,
				 "port"   => $LDAPServerPort})
  or die "Can't connect to the LDAP server ($LDAPServerHost:$LDAPServerPort)";

# Findout where schema is stored
my $sres = $conn->search(' ',
			 LDAP_SCOPE_BASE,
			 '(objectClass=*)',
			 0,
			 ('subSchemaSubEntry'))
  or die "Can't locate place where schema is stored";
my $entry = $sres->nextEntry();
my $subSchemaSubEntry  = ${$entry->attr('subSchemaSubEntry')->get()}[0];

# Get schema
$sres = $conn->search($subSchemaSubEntry,
		      LDAP_SCOPE_BASE,
		      '(objectclass=*)',
		      0,
		      ("attributeTypes", "ldapSyntaxes"))
  or die "Can't read schema";

my ($attr, $syn, $a, %attrList);
$entry = $sres->nextEntry();
while ($entry) {
  foreach $attr (@{$entry->attr('attributetypes')->get}) {
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

  $entry = $sres->nextEntry();
};

# Write automatic classes to files
my $oid;
foreach $oid (keys %attrList) {
  attributeHash2Class($attrList{$oid});
};

# Create .pod file with tree structure of attributes classes
my @array = values %$superclasses;
$tree{'Attribute'}=\@array;
open(TREE, ">$attrClassesPath/ClassTree.pod");
print TREE "="."head1 NAME

myPerlLDAP::attribute inheritance diagram

="."head1 DESCRIPTION\n\n";

print TREE printClassTree('Attribute', '  ');
print TREE "\n=cut\n";
close(TREE);

# Create Makefile.PL
open(MAKEFILEPL, ">$attrClassesPath/Makefile.PL");
print MAKEFILEPL "#!/usr/bin/perl -w

use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'          => 'myPerlLDAP::attribute',
    'VERSION'       => '$VERSION',
    'AUTHOR'        => 'Jan Tomasek <jan\@tomasek.cz>',
    'DISTNAME'      => 'myPerlLDAP-auto-attributes',
    'PMLIBDIRS'     => ['attribute'],
);\n";
close(MAKEFILEPL);

# Create MANIFEST
open(MANIFEST, ">$attrClassesPath/MANIFEST");
print MANIFEST "MANIFEST\n";
print MANIFEST "README\n";
print MANIFEST join("\n", @files);
close(MANIFEST);

# Create README
open(README, ">$attrClassesPath/README");
print README "This is just temporary package, any info you need is written in
myPerlLDAP documentation\n";
close(README);
