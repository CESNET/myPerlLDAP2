#!/usr/bin/perl -w

use ExtUtils::MakeMaker;
use strict;

my @files;

opendir(DIR, 'myPerlLDAP') or die "Can't open . dir: $!";
@files = grep { (!/^\.*$|\~$/) and (-f "myPerlLDAP/$_")} readdir(DIR);
close(DIR);

opendir(DIR, 'myPerlLDAP/Attribute') or die "Can't open myPerlLDAP dir: $!";
push @files,  map { "Attribute/$_"} grep { (!/^\.*$|\~$/) and (-f "myPerlLDAP/Attribute/$_")} readdir(DIR);
close(DIR);

my %PM;
my $file;
foreach $file (@files) {
  $PM{"myPerlLDAP/$file"}="\$(INST_LIBDIR)/$file";
};

WriteMakefile(
	      'NAME'		=> 'myPerlLDAP',
	      'DISTNAME'        => 'myPerlLDAP',
	      'VERSION_FROM'	=> 'myPerlLDAP/Conn.pm', # finds $VERSION
	      'PREREQ_PM'	=> {Mozilla::OpenLDAP::API => 1.4},
	      'AUTHOR'          => 'Jan Tomasek <jan@tomasek.cz>',
	      'PM'              => \%PM );
