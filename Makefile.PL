#!/usr/bin/perl -w

use ExtUtils::MakeMaker;
use strict;

sub MY::libscan {
  my ($self,$path) = @_;
  return '' if $path =~ m:\b(RCS|CVS|SCCS)\b: ;
  return '' if $path =~ m:~$: ;
  $path;
}

WriteMakefile(
	      'NAME'		=> 'myPerlLDAP',
	      'DISTNAME'        => 'myPerlLDAP',
	      'VERSION_FROM'	=> 'myPerlLDAP/conn.pm', # finds $VERSION
	      'PREREQ_PM'	=> {'perlOpenLDAP::API' => 1.4},
	      'AUTHOR'          => 'Jan Tomasek <jan@tomasek.cz>',
	      'PMLIBDIRS'       => ['myPerlLDAP'],
	     );
