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

BEGIN { $| = 1; print "1..1\n";}
#END {print "not ok 1\n" unless $SOK;}

use lib qw(/home/honza/proj/myPerlLDAP);
use strict;
use vars qw($SOK);

use myPerlLDAP::attribute;
use myPerlLDAP::entry;
use myPerlLDAP::searchResults;
use myPerlLDAP::utils;
use myPerlLDAP::conn;

use myPerlLDAP::attribute::_guide;
use myPerlLDAP::attribute::_fax;
use myPerlLDAP::attribute::_DN;
use myPerlLDAP::attribute::_enhancedGuide;
use myPerlLDAP::attribute::_binary;
use myPerlLDAP::attribute::_IA5String;
use myPerlLDAP::attribute::_matchingRuleDescription;
use myPerlLDAP::attribute::_teletexNumber;
use myPerlLDAP::attribute::_deliveryMethod;
use myPerlLDAP::attribute::_directoryString;
use myPerlLDAP::attribute::_generalizedTime;
use myPerlLDAP::attribute::_certificate;
use myPerlLDAP::attribute::_DITContentRuleDescription;
use myPerlLDAP::attribute::_DITStructureRuleDescription;
use myPerlLDAP::attribute::_certificateList;
use myPerlLDAP::attribute::_DSAQualitySyntax;
use myPerlLDAP::attribute::_integer;
use myPerlLDAP::attribute::_matchingRuleUseDescription;
use myPerlLDAP::attribute::_JPEG;
use myPerlLDAP::attribute::_nameAndOptionalUID;
use myPerlLDAP::attribute::_audio;
use myPerlLDAP::attribute::_certificatePair;
use myPerlLDAP::attribute::_nameFormDescription;
use myPerlLDAP::attribute::_binString;
use myPerlLDAP::attribute::_numericString;
use myPerlLDAP::attribute::_objectClassDescription;
use myPerlLDAP::attribute::_octetString;
use myPerlLDAP::attribute::_otherMailbox;
use myPerlLDAP::attribute::_OID;
use myPerlLDAP::attribute::_telephoneNumber;
use myPerlLDAP::attribute::_postalAddress;
use myPerlLDAP::attribute::_presentationAddress;
use myPerlLDAP::attribute::_supportedAlgorithm;
use myPerlLDAP::attribute::_protocolInformation;
use myPerlLDAP::attribute::_UTCTime;
use myPerlLDAP::attribute::_LDAPSyntaxDescription;
use myPerlLDAP::attribute::_attributeTypeDescription;
use myPerlLDAP::attribute::_dataQualitySyntax;
use myPerlLDAP::attribute::_facsimileTelephoneNumber;
use myPerlLDAP::attribute::_teletexTerminalIdentifier;

$SOK = 1;
print "ok 1\n" if $SOK;
