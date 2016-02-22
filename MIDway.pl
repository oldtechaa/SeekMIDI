#!/usr/bin/perl

# Copyright 2016 oldtechaa <oldtechaa@gmail.com>
# This software is licensed under the Perl license. (That means Artistic v1 or GPLv1.)

use strict;
use warnings;

use MIDI;

# writes the MIDI output to a file based on the list of events and the filename
sub midiWrite {
	my $midiEventsRef = shift;
	my $midiTicks = shift;
	my $midiFile = shift;
	
	my $midiTrack = MIDI::Track->new({'events' => $midiEventsRef});
	my $midiPiece = MIDI::Opus->new({'format' => 0, 'ticks' => $midiTicks, 'tracks' => [$midiTrack]});
	$midiPiece->write_to_file($midiFile);
};

my $events = [
	['patch_change',    0, 0,  19],
	['patch_change',    0, 1, 124],
	[     'note_on',    0, 0,  50, 64],
	[     'note_on',    0, 1,  50, 96],
	[    'note_off',   96, 0,  50, 64],
	[     'note_on',   96, 0,  49, 64],
	[    'note_off',   96, 1,  50, 96],
	[     'note_on',   96, 1,  49, 90],
	[    'note_off',  192, 0,  48, 64],
	[     'note_on',  192, 0,  49, 64],
	[    'note_off',  192, 1,  48, 90],
	[     'note_on',  192, 1,  49, 90],
	[    'note_off',  288, 0,  48, 64],
	[     'note_on',  288, 0,  49, 64],
	[    'note_off',  288, 1,  48, 90],
	[     'note_on',  288, 1,  49, 90],
	[    'note_off',  384, 0,  48, 64],
	[     'note_on',  384, 0,  49, 64],
	[    'note_off',  384, 1,  48, 90],
	[     'note_on',  384, 1,  49, 90],
	[    'note_off',  480, 0,  48, 64],
	[     'note_on',  480, 0,  49, 64],
	[    'note_off',  480, 1,  48, 90],
	[     'note_on',  480, 1,  49, 90],
	[    'note_off',  576, 0,  48, 64],
	[     'note_on',  576, 0,  49, 64],
	[    'note_off',  576, 1,  48, 90],
	[     'note_on',  576, 1,  49, 90],
	[    'note_off',  672, 0,  48, 64],
	[     'note_on',  672, 0,  49, 64],
	[    'note_off',  672, 1,  48, 90],
	[     'note_on',  672, 1,  49, 90],
	[    'note_off',  768, 0,  48, 64],
	[     'note_on',  768, 0,  49, 64],
	[    'note_off',  768, 1,  48, 90],
	[     'note_on',  768, 1,  49, 90],
	[    'note_off',  864, 0,  48, 64],
	[     'note_on',  864, 0,  49, 64],
	[    'note_off',  864, 1,  48, 90],
	[     'note_on',  864, 1,  49, 90],
	[    'note_off',  960, 0,  48, 64],
	[     'note_on',  960, 0,  49, 64],
	[    'note_off',  960, 1,  48, 90],
	[     'note_on',  960, 1,  49, 90],
	[    'note_off', 1056, 0,  48, 64],
	[    'note_off', 1056, 1,  48, 90]
];

midiWrite($events, 1056,"Milestone1Test.mid");
