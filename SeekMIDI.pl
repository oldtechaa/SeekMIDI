#!/usr/bin/perl

# Copyright 2016 oldtechaa <oldtechaa@gmail.com>
# This software is licensed under the Perl license. (That means Artistic v1 or GPL-1+.)

use strict;
use warnings;

# custom widget class; separate from main package below
package Gtk2::MIDIPlot;

use Gtk2;
use base 'Gtk2::DrawingArea';
use Cairo;

# makes a global draw object array ref; this array's referencing is complicated
my $gtkObjects = [];

# sets up the class; asks for the signals we need; sets main widget size
sub new {
  my $class = shift;
  my $this = bless Gtk2::DrawingArea->new(), $class;

  $this->signal_connect(expose_event => 'Gtk2::MIDIPlot::expose');
  $this->signal_connect(button_press_event => 'Gtk2::MIDIPlot::button');

  # this is needed to receive the button-press event from the GtkWidget
  $this->set_events("button-press-mask");

  $this->set_size_request(28800, 1024);

  return $this;
}

# refresh handler; handles drawing grid and objects
sub expose {
  my $this = shift;

  # makes new Cairo context
  my $thisCairo = Gtk2::Gdk::Cairo::Context->create($this->get_window());

  # sets drawing parameters for main grid
  # THIS LINE WIDTH SHOULD BE 1. THE LINE WIDTH GETS RESET SOMEWHERE THOUGH, SO THAT NEEDS TO BE FIXED. UNTIL THEN, 2 IT IS.--------FIXME---------
  $thisCairo->set_line_width(2);
  $thisCairo->set_source_rgb(0.75, 0.75, 0.75);

  # these two loops create the background grid
  my $inc = 0;
  for ($inc = 0; $inc <= 2400; $inc++) {
    $thisCairo->move_to($inc * 12, 0);
    $thisCairo->line_to($inc * 12, 1024);
  };

  for ($inc = 0; $inc <= 128; $inc++) {
    $thisCairo->move_to(0, $inc * 8);
    $thisCairo->line_to(28800, $inc * 8);
  };

  # the grid must be drawn before we start redrawing the note objects
  $thisCairo->stroke();

  # this checks for objects to draw and if there are any, it loops through them to check for note objects to draw, then draws the rectangles at the given coordinates.
  # as said above, the gtkObjects array referencing is complicated. Keep that in mind if trying to decipher it.
  if(@{$gtkObjects}) {
    $thisCairo->set_source_rgb(0, 0, 0);
    foreach(@{$gtkObjects}) {
      if(@{$_}[0] eq 'rect') {
        my ($x, $y) = (@{$_}[1], @{$_}[2]);

        $thisCairo->rectangle($x - ($x % 12), $y - ($y % 8), 12, 8);
        $thisCairo->fill();
      };
    };
  };

  $thisCairo->stroke();
}

# handles mouse-clicks on the custom widget
sub button {
  my $this = shift;
  my $event = shift;

  # if the left mouse button then add the coordinates to the draw objects array
  if ($event->button == 1) {
    # THIS PUSH HAS SLOPPY MEMORY HANDLING. MAKE IT SO IT CHECKS FOR A SIMILAR OBJECT FIRST. --------FIXME--------
    push(@{$gtkObjects}, ['rect', $event->x, $event->y]);
    $this->expose;
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

# We currently don't actually write out MIDI data. We're working on the custom widget.
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

my $mainWidgetScroll = Gtk2::ScrolledWindow->new();
my $mainWidget = Gtk2::MIDIPlot->new();
$mainWidgetScroll->add_with_viewport($mainWidget);
$mainVBox->pack_start($mainWidgetScroll, 1, 1, 0);

$window->signal_connect(destroy => sub{Gtk2->main_quit()});
$window->show_all();
Gtk2->main();

0;

# (($frames & 255) << 8) | $tpf