#!/usr/bin/perl -w

use ExtUtils::MakeMaker;
use strict;

$|=1;

my @files;

print "Looking for standard classes ... ";
opendir(DIR, 'myPerlLDAP') or die "Can't open . dir: $!";
@files = grep { (!/^\.*$|\~$/) and (-f "myPerlLDAP/$_")} readdir(DIR);
close(DIR);

my $found=scalar @files;
print "found: $found files ...";
if ($found==5) {
  print " all right\n";
} else {
  print " problem, this is shiped with 5 files\n";
};

print "Looking for attribute classes ... ";
opendir(DIR, 'myPerlLDAP/Attribute') or die "Can't open myPerlLDAP dir: $!";
push @files,  map { "Attribute/$_"} grep { (!/^\.*$|\~$/) and (-f "myPerlLDAP/Attribute/$_")} readdir(DIR);

my $std_found = scalar grep { /^Attribute\/_/ } @files;
$found = scalar @files - $found - $std_found;
close(DIR);
print "found: $std_found+$found files ...";
if (($std_found==40) and ($found>=8)) {
  print " all right\n";
} else {
  print " problem, this is shiped with 40+(>=8) files\n";
  if ($found<8) {
    print "Read README before running `perl Makefile.PL`\n";
    exit(0);
  };
};


my %PM;
my %MAN3PODS;
my $file;
print "Looking for files with embed POD documentation:\n";
foreach $file (@files) {
  $PM{"myPerlLDAP/$file"}="\$(INST_LIBDIR)/$file";
  if (`grep "^=head1" myPerlLDAP/$file`) {
    $file =~ s/\//\:\:/g;
    $file =~ s/\.pm^//;
    print "  myPerlLDAP::$file\n";
    $MAN3PODS{"myPerlLDAP/$file"}="\$(INST_MAN3DIR)/myPerlLDAP::$file.\$(MAN3EXT)";
  };
};

$MAN3PODS{'myPerlLDAP.pod'}='$(INST_MAN3DIR)/myPerlLDAP.$(MAN3EXT)';

WriteMakefile(
	      'NAME'		=> 'myPerlLDAP',
	      'DISTNAME'        => 'myPerlLDAP',
	      'VERSION_FROM'	=> 'myPerlLDAP/Conn.pm', # finds $VERSION
	      'PREREQ_PM'	=> {Mozilla::OpenLDAP::API => 1.4},
	      'AUTHOR'          => 'Jan Tomasek <jan@tomasek.cz>',
	      'PM'              => \%PM,
	      'MAN3PODS'        => \%MAN3PODS
	     );
