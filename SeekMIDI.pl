#!/usr/bin/perl

# SeekMIDI, a simple graphical MIDI sequencer
# Copyright (C) 2016  oldtechaa  <oldtechaa@gmail.com>

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;

# custom widget class; separate from main package below
package Gtk2::MIDIPlot;

use Gtk2;
use base 'Gtk2::ScrolledWindow';
use Cairo;

# makes a class-global array that holds true/false values for which note blocks are enabled, and the global drawing area
my @gtkObjects;
my $this;
my ($dragRow, $dragStart) = (-1, -1);

# sets up the class; asks for the signals we need; sets main widget size
sub new {
  my $class = shift;
  $this = Gtk2::DrawingArea->new();
  my $thisScroll = bless Gtk2::ScrolledWindow->new(), $class;
  $thisScroll->add_with_viewport($this);

  $this->signal_connect(expose_event => 'Gtk2::MIDIPlot::expose');
  $this->signal_connect(button_press_event => 'Gtk2::MIDIPlot::button');
  $this->signal_connect(button_release_event => 'Gtk2::MIDIPlot::release');
  $this->signal_connect(motion_notify_event => 'Gtk2::MIDIPlot::motion');

  # ask for mouse events from the DrawingArea
  $this->set_events(["button-press-mask", "button-motion-mask", "button-release-mask"]);

  $this->set_size_request(28800, 1024);

  # handles initializing the @gtkObjects array
  my $incx;
  my $incy;
  for($incx = 0; $incx < 2400; $incx++) {
    for($incy = 0; $incy < 128; $incy++) {
      $gtkObjects[$incx][$incy] = 0;
    }
  }

  return $thisScroll;
}

# refresh handler; handles drawing grid and objects
sub expose {
  $this->window->clear();

  # makes new Cairo context
  my $thisCairo = Gtk2::Gdk::Cairo::Context->create($this->get_window());

  # sets drawing color for main grid
  $thisCairo->set_source_rgb(0.75, 0.75, 0.75);

  # get the current scroll positions and size of the window, then convert to grid-blocks, adjusting to draw surrounding blocks also, and make sure we don't go out of bounds
  my ($x, $y, $width, $height) = (int($this->parent->get_hadjustment()->value / 12), int($this->parent->get_vadjustment()->value / 8), $this->parent->get_hadjustment()->page_size, $this->parent->get_vadjustment()->page_size);
  my $xmax = ($x + (int($width / 12) + 2));
  my $ymax = ($y + (int($height / 8) + 2));
  if($xmax > 2400) {$xmax = 2400};
  if($ymax > 128) {$ymax = 128};

  # these two loops create the background grid
  my $inc;
  for ($inc = $x; $inc <= $xmax; $inc++) {
    $thisCairo->move_to($inc * 12, $y * 8);
    $thisCairo->line_to($inc * 12, $ymax * 8);
  }
  for ($inc = $y; $inc <= $ymax; $inc++) {
    $thisCairo->move_to($x * 12, $inc * 8);
    $thisCairo->line_to($xmax * 12, $inc * 8);
  }

  # the grid must be drawn before we start redrawing the note objects
  $thisCairo->stroke();

  # this checks for events with their state set to true, then draws them 
  $xmax--;
  $ymax--;
  $thisCairo->set_source_rgb(0, 0, 0);
  for(my $incx = $x; $incx <= $xmax; $incx++) {
    for(my $incy = $y; $incy <= $ymax; $incy++) {
      if($gtkObjects[$incx][$incy] == 1) {
        $thisCairo->rectangle($incx * 12, $incy * 8, 12, 8);
      }
    }
  }

  # fill applies the black source onto the destination through the mask with rectangular holes
  $thisCairo->fill();
}

# handles mouse-clicks on the custom widget
sub button {
  my $event = $_[1];

  # if the left mouse button then invert this gridbox's state value
  if ($event->button == 1) {
    my ($xind, $yind) = (($event->x - ($event->x % 12)) / 12, ($event->y - ($event->y % 8)) / 8);
    $gtkObjects[$xind][$yind] = !$gtkObjects[$xind][$yind];
    if($gtkObjects[$xind][$yind] == 0) {
      expose($this);
    } else {
      # makes new Cairo context
      my $thisCairo = Gtk2::Gdk::Cairo::Context->create($this->get_window());

      $thisCairo->rectangle($xind * 12, $yind * 8, 12, 8);
      $thisCairo->fill();
    }

    # initialize drag variables
    if($dragStart == -1) {
      $dragStart = $xind;
    }
    if($dragRow == -1) {
      $dragRow = $yind;
    }
  }
}

# handles mouse drag across the widget
sub motion {
  my $event = $_[1];

  my ($xind, $yind) = (($event->x - ($event->x % 12)) / 12, ($event->y - ($event->y % 8)) / 8);

  # check if the underlying cell is set or not and if not, check which mouse button is pressed, then draw and set $gtkObjects
  if($gtkObjects[$xind][$dragRow] == 0) {
    if(grep('button1-mask', $event->state)) {
      # makes new Cairo context
      my $thisCairo = Gtk2::Gdk::Cairo::Context->create($this->get_window());

      # checks whether our overall drag is to the left or right and draws rectangles and updates $gtkObjects accordingly
      if($xind >= $dragStart) {
        $thisCairo->rectangle($dragStart * 12, $dragRow * 8, ($xind - $dragStart + 1) * 12, 8);
        for(my $inc = $dragStart; $inc <= $xind; $inc++) {
          $gtkObjects[$inc][$dragRow] = 1;
        }
      } else {
        $thisCairo->rectangle($xind * 12, $dragRow * 8, ($dragStart - $xind) * 12, 8);
        for(my $inc = $xind; $inc <= $dragStart; $inc++) {
          $gtkObjects[$inc][$dragRow] = 1;
        }
      }
      $thisCairo->fill();
    }
  }
}

# clears the current drag row and start point when the drag is ended
sub release {
  ($dragRow, $dragStart) = (-1, -1);
}

package main;

use MIDI;
use Gtk2 -init;
use Locale::gettext;

# writes the MIDI output to a file based on the list of events and the filename
sub midiWrite {
	my $midiEventsRef = shift;
	my $midiTicks = shift;
	my $midiFile = shift;
	
	my $midiTrack = MIDI::Track->new({'events' => $midiEventsRef});
	my $midiPiece = MIDI::Opus->new({'format' => 0, 'ticks' => $midiTicks, 'tracks' => [$midiTrack]});
	$midiPiece->write_to_file($midiFile);
}

# reads from the event file (future capability, not sure if it will be added) This is just for testing, to reach early milestones without an event entry control.
# would mainly be useful if there was ever a CLI version or if the GUI version had the capability to read non-MIDI projects.
sub evtOpen {
	my $evtFile = shift;
	my @events;

	open(my $evtHandle, "<", $evtFile);

	while (<$evtHandle>) {
		push(@events, [split(/,\s*/, $_)]);
	};

        close($evtHandle);

	return \@events;
}

# creates window with title
my $window = Gtk2::Window->new();
$window->set_title("SeekMIDI MIDI Sequencer");

# creates VBox for widgets along the top and the main widget area below
my $mainVBox = Gtk2::VBox->new(0, 6);
$window->add($mainVBox);

# creates HBox for widgets along the top
my $controlHBox = Gtk2::HBox->new(0, 6);
$mainVBox->pack_start($controlHBox, 0, 0, 0);

# creates label for filename entry
my $fileLabel = Gtk2::Label->new("Output Filename:");
$controlHBox->pack_start($fileLabel, 0, 0, 0);

# creates filename entry field
my $fileEntry = Gtk2::Entry->new();
$controlHBox->pack_start($fileEntry, 0, 0, 0);

# creates file save button
my $saveButton = Gtk2::Button->new("_Save");
$controlHBox->pack_start($saveButton, 0, 0, 0);
$saveButton->signal_connect(clicked => sub{midiWrite(evtOpen("events.in"), 96, $fileEntry->get_text())});

# creates main widget
my $mainWidget = Gtk2::MIDIPlot->new();
$mainVBox->pack_start($mainWidget, 1, 1, 0);

# starts up the GUI
$window->signal_connect(destroy => sub{Gtk2->main_quit()});
$window->show_all();
Gtk2->main();

0;