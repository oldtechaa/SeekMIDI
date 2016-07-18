#!/usr/bin/perl

# SeekMIDI, a simple graphical MIDI sequencer
# Copyright (C) 2016  oldtechaa  <oldtechaa@gmail.com>
# Version 0.1.0

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
use base 'Gtk2::VBox';
use Cairo;
use Pango;

# makes a class-global array that holds note objects, and the global drawing area
my @notes;

my $this;
my $thisScroll;
my $volSlider;
my $HBox;

my ($dragRow, $dragStart, $dragMode) = (-1, -1, -1);

my @keys = (0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0,
             0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0,
             0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0,
             0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0,
             0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0,
             0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0,
             0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0,
             0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0,
             0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0,
             0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0,
             0, 1, 0, 1, 0, 0, 1, 0);

my @selectSingle = (-1, -1);

my ($cellWidth, $cellHeight, $numCells, $cellTime) = (12, 8, 2400, 6);

# sets up the class; asks for the signals we need; sets main widget size
sub new {
  $this = Gtk2::DrawingArea->new();
  my $topVBox = bless Gtk2::VBox->new();
  $thisScroll = Gtk2::ScrolledWindow->new();
  $HBox = Gtk2::HBox->new();
  my $volLabel = Gtk2::Label->new('Volume: ');
  $volSlider = Gtk2::HScale->new_with_range(0, 127, 1);

  $topVBox->pack_start($thisScroll, 1, 1, 0);
  $topVBox->pack_start($HBox, 0, 0, 0);

  $thisScroll->add_with_viewport($this);

  $HBox->pack_start($volLabel, 0, 0, 0);
  $HBox->pack_start($volSlider, 1, 1, 0);

  $this->signal_connect(expose_event => 'Gtk2::MIDIPlot::expose');
  $this->signal_connect(button_press_event => 'Gtk2::MIDIPlot::button');
  $this->signal_connect(button_release_event => 'Gtk2::MIDIPlot::release');
  $this->signal_connect(motion_notify_event => 'Gtk2::MIDIPlot::motion');
  $thisScroll->get_hadjustment->signal_connect(value_changed => 'Gtk2::MIDIPlot::expose');
  $thisScroll->get_vadjustment->signal_connect(value_changed => 'Gtk2::MIDIPlot::expose');

  # ask for mouse events from the DrawingArea
  $this->set_events(['button-press-mask', 'button-motion-mask', 'button-release-mask']);

  $this->set_size_request(($numCells + 3) * $cellWidth, 130 * $cellHeight);

  return $topVBox;
}

# refresh handler; handles drawing grid and objects
sub expose {
  $this->window->clear();

  # makes new Cairo context
  my $thisCairo = Gtk2::Gdk::Cairo::Context->create($this->get_window());

  # sets drawing color for main grid
  $thisCairo->set_source_rgb(0.75, 0.75, 0.75);

  # get the current scroll positions and size of the window, then convert to grid-blocks, adjusting to draw surrounding blocks also, and make sure we don't go out of bounds
  my ($xmin, $ymin, $width, $height) = (int($thisScroll->get_hadjustment()->value / $cellWidth) + 3, int($thisScroll->get_vadjustment()->value / $cellHeight) + 2, $thisScroll->get_hadjustment()->page_size - ($cellWidth * 3), $thisScroll->get_vadjustment()->page_size - ($cellHeight * 2));
  my $xmax = ($xmin + (int($width / $cellWidth) + 2));
  my $ymax = ($ymin + (int($height / $cellHeight) + 2));
  $xmax = $numCells + 3 if $xmax > $numCells + 3;
  $ymax = 130 if $ymax > 130;

  # these two loops create the background grid
  my $inc;
  for ($xmin .. $xmax) {
    #if (($_ - 3) % (96 / $cellTime) == 0) {
    #  $thisCairo->stroke();
    #  $thisCairo->set_source_rgb(0.5, 0.5, 0.5);
    #}
    $thisCairo->move_to($_ * $cellWidth, $ymin * $cellHeight);
    $thisCairo->line_to($_ * $cellWidth, $ymax * $cellHeight);
    #if (($_ - 3) % (96 / $cellTime) == 0) {
    #  $thisCairo->stroke();
    #  $thisCairo->set_source_rgb(0.75, 0.75, 0.75);
    #}
  }
  for ($ymin .. $ymax) {
    $thisCairo->move_to($xmin * $cellWidth, $_ * $cellHeight);
    $thisCairo->line_to($xmax * $cellWidth, $_ * $cellHeight);
  }
  
  # the grid must be drawn before we start redrawing the key objects
  $thisCairo->stroke();

  $thisCairo->set_source_rgb(0.5, 0.5, 0.5);

  my $thisPango = Pango::Cairo::create_layout($thisCairo);
  my $thisPangoAttr = Pango::AttrList->new();
  $thisPangoAttr->insert(Pango::AttrSize->new(8192));
  $thisPango->set_attributes($thisPangoAttr);
  for ($xmin - 3 .. $xmax - 3) {
    if ($_ % (96 / $cellTime) == 0) {
      $thisCairo->move_to(($_ + 3) * $cellWidth, $ymin * $cellHeight);
      $thisCairo->line_to(($_ + 3) * $cellWidth, $ymax * $cellHeight);
      
      $thisPango->set_text($_ / (96 / $cellTime));
      my ($PangoWidth, $PangoHeight) = $thisPango->get_size();
      $thisCairo->move_to($_ * $cellWidth - $PangoWidth / Gtk2::Pango->scale() / 2 + 3 * $cellWidth, $ymin * $cellHeight - ($cellHeight * 1.5));
      Pango::Cairo::show_layout($thisCairo, $thisPango);
    }
  }
  if ($ymin == 2) {
    $thisCairo->move_to($xmin * $cellWidth, 2 * $cellHeight);
    $thisCairo->line_to($xmax * $cellWidth, 2 * $cellHeight);
  }
  if ($ymax == 130) {
    $thisCairo->move_to($xmin * $cellWidth, 130 * $cellHeight);
    $thisCairo->line_to($xmax * $cellWidth, 130 * $cellHeight);
  }
  
  $thisCairo->stroke();

  $thisCairo->set_source_rgb(0, 0, 0);
  for ($ymin .. $ymax - 1) {
    if ($keys[127 - ($_ - 2)] == 1) {
      $thisCairo->rectangle(($xmin - 3) * $cellWidth, $_ * $cellHeight + 1, ($cellWidth * 3) * 0.8, $cellHeight * 0.75);
    }
  }
  
  # this checks for events with their state set to true, then draws them 
  for ($ymin .. $ymax - 1) {
    if (is_Enabled($xmin - 3, $_ - 2)) {
      my $startNote = $notes[$xmin - 3][$_ - 2][2];
      $thisCairo->rectangle($xmin * $cellWidth, $_ * $cellHeight, ($notes[$startNote][$_ - 2][3] - (($xmin - 3) - $startNote)) * $cellWidth, $cellHeight);
    }
  }
  for my $incx ($xmin + 1 .. $xmax - 1) {
    for my $incy ($ymin .. $ymax - 1) {
      if (is_Enabled($incx - 3, $incy - 2) && $notes[$incx - 3][$incy - 2][1] == 0) {
        $thisCairo->rectangle($incx * $cellWidth, $incy * $cellHeight, $notes[$incx - 3][$incy - 2][3] * $cellWidth, $cellHeight);
      }
    }
  }

  # fill applies the black source onto the destination through the mask with rectangular holes
  $thisCairo->fill();
}

# handles mouse-clicks on the custom widget
sub button {
  my $event = $_[1];

  my ($xcell, $ycell) = (($event->x - ($event->x % $cellWidth)) / $cellWidth, ($event->y - ($event->y % $cellHeight)) / $cellHeight);
  my ($xmin, $ymin) = (int($thisScroll->get_hadjustment()->value / $cellWidth) + 3, int($thisScroll->get_vadjustment()->value / $cellHeight) + 2);
  my ($x, $y) = ($xcell - 3, $ycell - 2);
  
  my $maxCell = $numCells - 1;

  # if the left mouse button then invert this gridbox's state value
  if ($event->button == 1) {
    if ($xcell >= $xmin && $ycell >= $ymin) {
      if (is_Enabled($x, $y)) {
        # selection or moving
      } else {
        addNote($x, $y);

        # makes new Cairo context
        my $thisCairo = Gtk2::Gdk::Cairo::Context->create($this->get_window());

        $thisCairo->rectangle(($notes[$x][$y][2] + 3) * $cellWidth, $ycell * $cellHeight, $notes[$notes[$x][$y][2]][$y][3] * $cellWidth, $cellHeight);
        $thisCairo->fill();
        
        $dragMode = 0;
        $dragRow = $y;
      }
    }
  # if the right mouse button remove the note
  } elsif ($event->button == 3) {
    if ($xcell >= $xmin && $ycell >= $ymin) {
      if (is_Enabled($x, $y)) {
        for ($notes[$x][$y][2] .. $notes[$x][$y][2] + $notes[$notes[$x][$y][2]][$y][3] - 1) {
          $notes[$_][$y][0] = 0;
        }
        expose();
      }
    }
  }
}

# handles mouse drag across the widget
sub motion {
  my $event = $_[1];
  
  my ($xcell, $ycell) = (($event->x - ($event->x % $cellWidth)) / $cellWidth, ($event->y - ($event->y % $cellHeight)) / $cellHeight);
  my ($xmin, $ymin) = (int($thisScroll->get_hadjustment()->value / $cellWidth) + 3, int($thisScroll->get_vadjustment()->value / $cellHeight) + 2);
  my ($x, $y) = ($xcell - 3, $ycell - 2);
  
  # check if the underlying cell is set or not and if not, check which mouse button is pressed, then draw and set $notes
  if ($dragMode == 0) {
    if ($xcell >= $xmin) {
      addNote($x, $dragRow);
      
      # makes new Cairo context
      my $thisCairo = Gtk2::Gdk::Cairo::Context->create($this->get_window());
      
      $thisCairo->rectangle(($notes[$x][$dragRow][2] + 3) * $cellWidth, ($dragRow + 2) * $cellHeight, $notes[$notes[$x][$dragRow][2]][$dragRow][3] * $cellWidth, $cellHeight);
      $thisCairo->fill();
    }
  }
}

# clears the current drag row, start point, and drag mode when the drag is ended
sub release {
  ($dragRow, $dragMode) = (-1, -1);
}

sub addNote {
  my ($x, $y) = @_;
  
  @{$notes[$x][$y]}[0 .. 2] = (1, 0, $x);
  if (is_Enabled($x - 1, $y)) {
    @{$notes[$x][$y]}[1 .. 2] = (1, $notes[$x - 1][$y][2]);
  }
  for ($notes[$x][$y][2] + 1 .. $numCells) {
    if (is_Enabled($_, $y)) {
      @{$notes[$_][$y]}[1 .. 2] = (1, $notes[$x][$y][2]);
    } else {
      $notes[$notes[$x][$y][2]][$y][3] = $_  - $notes[$x][$y][2];
      last;
    }
  }
}

sub getMIDI {
  my @events;

  push(@events, ['patch_change', 0, 0, 0]);

  for (0 .. 127) {
    if (is_Enabled(0, $_)) {
      push(@events, ['note_on', 0, 0, 127 - $_, 127]);
    }
  }
  my $delta = $cellTime;
  for my $incx (1 .. $numCells) {
    for my $incy (0 .. 127) {
      if (!is_Enabled($incx, $incy) && is_Enabled($incx - 1, $incy)) {
        push(@events, ['note_off', $delta, 0, 127 - $incy, 127]);
        $delta = 0;
      } elsif (is_Enabled($incx, $incy) && !is_Enabled($incx - 1, $incy)) {
        push(@events, ['note_on', $delta, 0, 127 - $incy, 127]);
        $delta = 0;
      }
    }
    $delta += $cellTime;
  }

  return \@events;
}

sub get_HBox {
  return $HBox;
}

sub is_Enabled {
  my ($x, $y) = @_;
  if ($notes[$x][$y][0] && $notes[$x][$y][0] == 1) {
    return 1;
  } else {
    return 0;
  }
}

package main;

# append to @INC the script dir's subdir 'lib' for MIDI.pm
use FindBin;
use File::Spec;
use lib File::Spec->catdir($FindBin::Bin, '../lib');

use MIDI;
use Gtk2 -init;
# use Locale::gettext;

# writes the MIDI output to a file based on the list of events and the filename
sub midiWrite {
	my $midiEventsRef = shift;
	my $midiTicks = shift;
	my $midiFile = shift;
	
	my $midiTrack = MIDI::Track->new({'events' => $midiEventsRef});
	my $midiPiece = MIDI::Opus->new({'format' => 0, 'ticks' => $midiTicks, 'tracks' => [$midiTrack]});
	$midiPiece->write_to_file($midiFile);
}

# creates window with title
my $window = Gtk2::Window->new();
$window->set_title('SeekMIDI MIDI Sequencer');

# creates VBox for widgets along the top and the main widget area below
my $mainVBox = Gtk2::VBox->new(0, 6);
$window->add($mainVBox);

# creates HBox for widgets along the top
my $controlHBox = Gtk2::HBox->new(0, 6);
$mainVBox->pack_start($controlHBox, 0, 0, 0);

# creates label for filename entry
my $fileLabel = Gtk2::Label->new('Output Filename:');
$controlHBox->pack_start($fileLabel, 0, 0, 0);

# creates filename entry field
my $fileEntry = Gtk2::Entry->new();
$controlHBox->pack_start($fileEntry, 0, 0, 0);

# creates file save button
my $saveButton = Gtk2::Button->new('_Save');
$controlHBox->pack_start($saveButton, 0, 0, 0);

# creates main widget
my $mainWidget = Gtk2::MIDIPlot->new();
$mainVBox->pack_start($mainWidget, 1, 1, 0);
$saveButton->signal_connect(clicked => sub{midiWrite($mainWidget->getMIDI(), 24, $fileEntry->get_text()) if $fileEntry->get_text() ne ""});

# starts up the GUI
$window->signal_connect(destroy => sub{Gtk2->main_quit()});
$window->show_all();
$mainWidget->get_HBox()->hide();
Gtk2->main();

0;
