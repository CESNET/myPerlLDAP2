#!/usr/bin/perl -w

use ExtUtils::MakeMaker;
use strict;

WriteMakefile(
	      'NAME'		=> 'myPerlLDAP',
	      'DISTNAME'        => 'myPerlLDAP',
	      'VERSION_FROM'	=> 'myPerlLDAP/Conn.pm', # finds $VERSION
	      'PREREQ_PM'	=> {'Mozilla::OpenLDAP::API' => 1.4},
	      'AUTHOR'          => 'Jan Tomasek <jan@tomasek.cz>',
	      'PMLIBDIRS'       => ['myPerlLDAP'],
	     );
