#!/usr/bin/perl

# Copyright 2016 oldtechaa <oldtechaa@gmail.com>
# This software is licensed under the Perl license. (That means Artistic v1 or GPL-1+.)

use strict;
use warnings;

use MIDI;
use Gtk2 -init;

# writes the MIDI output to a file based on the list of events and the filename
sub midiWrite {
	my $midiEventsRef = shift;
	my $midiTicks = shift;
	my $midiFile = shift;
	
	my $midiTrack = MIDI::Track->new({'events' => $midiEventsRef});
	my $midiPiece = MIDI::Opus->new({'format' => 0, 'ticks' => $midiTicks, 'tracks' => [$midiTrack]});
	$midiPiece->write_to_file($midiFile);
};

# reads from the event file (future capability, not sure if it will be added) This is just for testing, to reach Milestone2.
# would mainly be useful if there was ever a CLI version or if the GUI version had the capability to read non-MIDI projects.
sub evtOpen {
	my $evtFile = shift;
	my @events;

	open(my $evtHandle, "<", $evtFile);
	my @evtLines = <$evtHandle>;

	foreach (@evtLines) {
		push(@events, [split(/,\s*/, $_)]);
	};

	return \@events;
};

# This can be changed around to reflect whatever type of track and file we need
# midiWrite(evtOpen("events.in"), 96, "Milestone2.mid");

my $window = Gtk2::Window->new();
$window->set_title("SeekMIDI MIDI Sequencer");
$window->signal_connect(destroy => sub{Gtk2->main_quit;});
$window->show_all();
Gtk2->main;

0;

# (($frames & 255) << 8) | $tpf