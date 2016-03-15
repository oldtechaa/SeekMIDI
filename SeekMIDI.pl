#!/usr/bin/perl

# Copyright 2016 oldtechaa <oldtechaa@gmail.com>
# This software is licensed under the Perl license. (That means Artistic v1 or GPL-1+.)

use strict;
use warnings;

package Gtk2::MIDIPlot;

use Gtk2;
use base 'Gtk2::DrawingArea';
use Cairo;

sub new {
  my $class = shift;
  my $this = bless Gtk2::DrawingArea->new(), $class;

  $this->signal_connect(expose_event => 'Gtk2::MIDIPlot::draw');
  $this->signal_connect(button_press_event => 'Gtk2::MIDIPlot::button_press');

  $this->set_events("button-press-mask");

  return $this;
}

sub draw {
  my $this = shift;

  $this->set_size_request(28800, 1536);
  my $thisCairo = Gtk2::Gdk::Cairo::Context->create($this->get_window());

  $thisCairo->set_line_width(1);
  $thisCairo->set_source_rgb(0.75, 0.75, 0.75);
  my $inc;
  for ($inc = 0; $inc <= 2400; $inc++) {
    $thisCairo->move_to($inc * 12, 0);
    $thisCairo->line_to($inc * 12, 1536);
  };
  for ($inc = 0; $inc <= 128; $inc++) {
    $thisCairo->move_to(0, $inc * 12);
    $thisCairo->line_to(28800, $inc * 12);
  };
  $thisCairo->stroke();
}

sub button_press {
  my $this = shift;
  my $event = shift;

  if ($event->button == 1) {
    my $x = $event->x;
    my $y = $event->y;

    my $thisCairo = Gtk2::Gdk::Cairo::Context->create($this->get_window());
    $thisCairo->rectangle($x - ($x % 12), $y - ($y % 12), 12, 12);
    $thisCairo->fill();
    $thisCairo->stroke();
  };
}

package main;

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

# reads from the event file (future capability, not sure if it will be added) This is just for testing, to reach early milestones without an event entry control.
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

my $mainVBox = Gtk2::VBox->new(0, 6);
$window->add($mainVBox);

my $controlHBox = Gtk2::HBox->new(0, 6);
$mainVBox->pack_start($controlHBox, 0, 0, 0);

my $fileLabel = Gtk2::Label->new("Output Filename:");
$controlHBox->pack_start($fileLabel, 0, 0, 0);

my $fileEntry = Gtk2::Entry->new();
$controlHBox->pack_start($fileEntry, 0, 0, 0);

my $saveButton = Gtk2::Button->new("_Save");
$controlHBox->pack_start($saveButton, 0, 0, 0);
$saveButton->signal_connect(clicked => sub{midiWrite(evtOpen("events.in"), 96, $fileEntry->get_text())});

#my $mainWidgetScroll = Gtk2::ScrolledWindow->new();
#my $mainWidgetTable = Gtk2::Table->new(128, 128, 1);
#$mainWidgetScroll->add_with_viewport($mainWidgetTable);
#$mainVBox->pack_start($mainWidgetScroll, 1, 1, 0);

#my $tableButton = Gtk2::Button->new();
#$mainWidgetTable->attach($tableButton, 0, 1, 0, 1, "expand", "expand", 0, 0);

my $mainWidgetScroll = Gtk2::ScrolledWindow->new();
my $mainWidget = Gtk2::MIDIPlot->new();
$mainWidgetScroll->add_with_viewport($mainWidget);
$mainVBox->pack_start($mainWidgetScroll, 1, 1, 0);

$window->signal_connect(destroy => sub{Gtk2->main_quit()});
$window->show_all();
Gtk2->main();

0;

# (($frames & 255) << 8) | $tpf