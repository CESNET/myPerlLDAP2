#!/usr/bin/perl -w

use ExtUtils::MakeMaker;
use strict;

WriteMakefile(
	      'NAME'		=> 'myPerlLDAP',
	      'DISTNAME'        => 'myPerlLDAP',
	      'VERSION_FROM'	=> 'myPerlLDAP/conn.pm', # finds $VERSION
	      'PREREQ_PM'	=> {'perlOpenLDAP::API' => 1.4},
	      'AUTHOR'          => 'Jan Tomasek <jan@tomasek.cz>',
	      'PMLIBDIRS'       => ['myPerlLDAP'],
	     );
