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

# ALWAYS MAINTAIN NO WARNINGS AND NO ERRORS!
use warnings;
use strict;

# custom widget class; separate from main package below
package Gtk3::MIDIPlot;

# invoke dependency modules
use Gtk3;
use base 'Gtk3::VBox';
use Pango;

# makes a package-global array that holds note objects, and the global drawing area
my @notes;

# set up package-global variables for widgets that need to be accessed throughout the package
my $this;
my $thisScroll;
my $volSlider;
my $VBox;

# initialize the drag variables to a no-drag state
my ($dragRow, $dragStart, $dragMode) = (-1, -1, -1);

# set up black-white key pattern on left sidebar
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

# set up single note selection
my @selSingle = (-1, -1);

# set some global constants
my ($cellWidth, $cellHeight, $numCells, $cellTime, $defaultVol) = (12, 8, 2400, 6, 127);

# sets up the class; asks for the signals we need; sets main widget size
sub new {
  $this = Gtk3::DrawingArea->new();
  my $topHBox = bless Gtk3::Box->new('horizontal', 6);
  $thisScroll = Gtk3::ScrolledWindow->new();
  $VBox = Gtk3::Box->new('vertical', 6);
  my $volLabel = Gtk3::Label->new('Vol: ');
  $volSlider = Gtk3::Scale->new_with_range('vertical', 0, 127, 1);
  
  $volSlider->set_inverted(1);

  $topHBox->pack_start($thisScroll, 1, 1, 0);
  $topHBox->pack_start($VBox, 0, 0, 0);

  $thisScroll->add_with_viewport($this);

  $VBox->pack_start($volLabel, 0, 0, 0);
  $VBox->pack_start($volSlider, 1, 1, 0);

  $this->signal_connect('draw' => 'Gtk3::MIDIPlot::refresh');
  $this->signal_connect('button_press_event' => 'Gtk3::MIDIPlot::button');
  $this->signal_connect('motion_notify_event' => 'Gtk3::MIDIPlot::motion');
  $this->signal_connect('button_release_event' => 'Gtk3::MIDIPlot::release');
  $this->signal_connect('realize' => 'Gtk3::MIDIPlot::set_mouse_events');
  
  $thisScroll->get_hadjustment->signal_connect('value_changed' => 'Gtk3::MIDIPlot::queue_draw');
  $thisScroll->get_vadjustment->signal_connect('value_changed' => 'Gtk3::MIDIPlot::queue_draw');
  
  $volSlider->get_adjustment->signal_connect('value_changed' => 'Gtk3::MIDIPlot::volChanged');

  $this->set_size_request(($numCells + 3) * $cellWidth, 130 * $cellHeight);

  return $topHBox;
}

# refresh handler; handles drawing grid and objects
# NOTE: $xmin, $ymin refer to grid area coordinates, NOT global drawing area coordinates. 3 cells on the left and 2 on top are taken by sidebar and header
sub refresh {
  # gets Cairo context
  my $thisCairo = $_[1];

  # sets drawing color for main grid
  $thisCairo->set_source_rgb(0.75, 0.75, 0.75);

  # get the current scroll positions and size of the window, then convert to grid-blocks, adjusting to draw surrounding blocks also, and make sure we don't go out of bounds
  my ($xmin, $ymin, $width, $height) = (int($thisScroll->get_hadjustment()->get_value() / $cellWidth) + 3, int($thisScroll->get_vadjustment()->get_value() / $cellHeight) + 2, $thisScroll->get_hadjustment()->get_page_size() - ($cellWidth * 3), $thisScroll->get_vadjustment()->get_page_size() - ($cellHeight * 2));
  my $xmax = ($xmin + (int($width / $cellWidth) + 2));
  my $ymax = ($ymin + (int($height / $cellHeight) + 2));
  $xmax = $numCells + 3 if $xmax > $numCells + 3;
  $ymax = 130 if $ymax > 130;

  # these two loops create the background grid
  my $inc;
  for ($xmin .. $xmax) {
    $thisCairo->move_to($_ * $cellWidth, $ymin * $cellHeight);
    $thisCairo->line_to($_ * $cellWidth, $ymax * $cellHeight);
  }
  for ($ymin .. $ymax) {
    $thisCairo->move_to($xmin * $cellWidth, $_ * $cellHeight);
    $thisCairo->line_to($xmax * $cellWidth, $_ * $cellHeight);
  }
  
  # the grid must be drawn before we start redrawing the key objects
  $thisCairo->stroke();

  $thisCairo->set_source_rgb(0.5, 0.5, 0.5);

  # set up Pango for time header
  my $thisPango = Pango::Cairo::create_layout($thisCairo);
  my $thisPangoAttr = Pango::AttrList->new();
  $thisPangoAttr->insert(Pango::AttrSize->new(8192));
  $thisPango->set_attributes($thisPangoAttr);
  
  # draw time header and darker lines on time divisions
  for ($xmin - 3 .. $xmax - 3) {
    if ($_ % (96 / $cellTime) == 0) {
      $thisCairo->move_to(($_ + 3) * $cellWidth, $ymin * $cellHeight);
      $thisCairo->line_to(($_ + 3) * $cellWidth, $ymax * $cellHeight);
      
      $thisPango->set_text($_ / (96 / $cellTime));
      my ($PangoWidth, $PangoHeight) = $thisPango->get_size();
      $thisCairo->move_to($_ * $cellWidth - $PangoWidth / Pango->scale() / 2 + 3 * $cellWidth, $ymin * $cellHeight - ($cellHeight * 1.5));
      Pango::Cairo::show_layout($thisCairo, $thisPango);
    }
  }
  
  # draw darker top and bottom lines
  if ($ymin == 2) {
    $thisCairo->move_to($xmin * $cellWidth, 2 * $cellHeight);
    $thisCairo->line_to($xmax * $cellWidth, 2 * $cellHeight);
  }
  if ($ymax == 130) {
    $thisCairo->move_to($xmin * $cellWidth, 130 * $cellHeight);
    $thisCairo->line_to($xmax * $cellWidth, 130 * $cellHeight);
  }
  
  # stroke the darker lines
  $thisCairo->stroke();

  # create the piano key sidebar
  $thisCairo->set_source_rgb(0, 0, 0);
  for ($ymin .. $ymax - 1) {
    if ($keys[127 - ($_ - 2)] == 1) {
      $thisCairo->rectangle(($xmin - 3) * $cellWidth, $_ * $cellHeight + 1, ($cellWidth * 3) * 0.8, $cellHeight * 0.75);
    }
  }
  
  # this checks for events with their state set to true, then draws them, scanning the leftmost column first, then all others
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
  my ($xmin, $ymin) = (int($thisScroll->get_hadjustment()->get_value() / $cellWidth) + 3, int($thisScroll->get_vadjustment()->get_value() / $cellHeight) + 2);
  my ($x, $y) = ($xcell - 3, $ycell - 2);
  
  my $maxCell = $numCells - 1;

  # left mouse button
  if ($event->button == 1) {
    if ($xcell >= $xmin && $ycell >= $ymin) {
      if (is_Enabled($x, $y)) {
        # select a note
        selNote($notes[$x][$y][2], $y);
      } else {
        # add a note and refresh
        addNote($x, $y);
        queue_draw();
        
        $dragMode = 0;
        $dragRow = $y;
      }
    }
  # right mouse button
  } elsif ($event->button == 3) {
    if ($xcell >= $xmin && $ycell >= $ymin) {
      if (is_Enabled($x, $y)) {
        # remove the note
        @selSingle = (-1, -1) if @selSingle = ($notes[$x][$y][2], $y);

        for ($notes[$x][$y][2] .. $notes[$x][$y][2] + $notes[$notes[$x][$y][2]][$y][3] - 1) {
          $notes[$_][$y][0] = 0;
        }
      } else {
        # turn off selection
        @selSingle = (-1, -1);
      }
      # hide volume slider
      $VBox->hide();
      queue_draw();
    }
  }
}

# handles mouse drag across the widget
sub motion {
  my $event = $_[1];
  
  my ($xcell, $ycell) = (($event->x - ($event->x % $cellWidth)) / $cellWidth, ($event->y - ($event->y % $cellHeight)) / $cellHeight);
  my ($xmin, $ymin) = (int($thisScroll->get_hadjustment()->get_value() / $cellWidth) + 3, int($thisScroll->get_vadjustment()->get_value() / $cellHeight) + 2);
  my ($x, $y) = ($xcell - 3, $ycell - 2);
  
  # check if the underlying cell is set or not and if not, check which mouse button is pressed, then set $notes and refresh
  if ($dragMode == 0) {
    if ($xcell >= $xmin) {
      addNote($x, $dragRow);
      queue_draw();
    }
  }
}

# clears the current drag row and mode when the drag is ended
sub release {
  ($dragRow, $dragMode) = (-1, -1);
}

# creates a new note and selects it
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
  
  selNote($notes[$x][$y][2], $y);
}

# sets a note's selected attribute to true
sub selNote {
	my ($x, $y) = @_;
	@selSingle = ($x, $y);
	
  # show volume slider for selected note
  $VBox->show();
  if (!$notes[$notes[$x][$y][2]][$y][4]) {
    $notes[$notes[$x][$y][2]][$y][4] = $defaultVol;
  }
  $volSlider->get_adjustment()->set_value($notes[$notes[$x][$y][2]][$y][4]);
}

# changes volume attribute of a note
sub volChanged {
  $notes[$selSingle[0]][$selSingle[1]][4] = shift->get_value();
}

# gets the actual MIDI data for output
sub getMIDI {
  my @events;

  push (@events, ['patch_change', 0, 0, $_[1]]);

  for (0 .. 127) {
    if (is_Enabled(0, $_)) {
      push (@events, ['note_on', 0, 0, 127 - $_, $notes[0][$_][4]]);
    }
  }
  my $delta = $cellTime;
  for my $incx (1 .. $numCells) {
    for my $incy (0 .. 127) {
      if (!is_Enabled($incx, $incy) && is_Enabled($incx - 1, $incy)) {
        push (@events, ['note_off', $delta, 0, 127 - $incy, $notes[$notes[$incx - 1][$incy][2]][$incy][4]]);
        $delta = 0;
      } elsif (is_Enabled($incx, $incy) && !is_Enabled($incx - 1, $incy)) {
        push (@events, ['note_on', $delta, 0, 127 - $incy, $notes[$incx][$incy][4]]);
        $delta = 0;
      }
    }
    $delta += $cellTime;
  }

  return \@events;
}

# makes it so we can get the VBox from outside the package
sub get_VBox {
  return $VBox;
}

# tells us whether a cell contains (part of) a note
sub is_Enabled {
  my ($x, $y) = @_;
  if ($notes[$x][$y][0]) {
    return 1;
  } else {
    return 0;
  }
}

# queue a refresh
sub queue_draw {
	$this->queue_draw();
}

# ask for mouse events from the DrawingArea
sub set_mouse_events {
  $this->get_window()->set_events(['button-press-mask', 'button-motion-mask', 'button-release-mask']);
}

package main;

# append to @INC the script dir's subdir 'lib' for MIDI.pm
use FindBin;
use File::Spec;
use lib File::Spec->catdir($FindBin::Bin, '../lib');

use MIDI;
use Gtk3;
# use Locale::gettext;

use Glib::Object::Introspection;
Glib::Object::Introspection->setup('basename' => 'Gio', 'version' => '2.0', 'package' => 'Glib::IO');

# writes the MIDI output to a file based on the list of events and the filename that the user enters in a FileChooserDialog
sub midiWrite {
  my @dataArr = @{$_[2]};
  
  my $mainWidget = $dataArr[0];
	my $midiEventsRef = $mainWidget->getMIDI($dataArr[1]->get_active());
	my $midiTicks = $dataArr[2];
  
  my $fileDialog = Gtk3::FileChooserDialog->new('Save As', $dataArr[3], 'save', '_Cancel', 'cancel', '_Save', 'ok');
  
  if ($fileDialog->run() eq 'ok') {
    my $midiFile = $fileDialog->get_filename();
    $fileDialog->destroy();

  	my $midiTrack = MIDI::Track->new({'events' => $midiEventsRef});
	  my $midiPiece = MIDI::Opus->new({'format' => 0, 'ticks' => $midiTicks, 'tracks' => [$midiTrack]});
	  $midiPiece->write_to_file($midiFile);
  } else {
    $fileDialog->destroy();
  }
}

# insert entries into the patch list and space properly for vertical alignment
sub patchPopulate {
  my @patches = ('Grand Piano',
                 'Bright Acoustic Piano',
                 'Electric Grand Piano',
                 'Honky-Tonk Piano',
                 'Electric Piano 1',
                 'Electric Piano 2',
                 'Harpsichord',
                 'Clavinet',
                 'Celesta',
                 'Glockenspiel',
                 'Music Box',
                 'Vibraphone',
                 'Marimba',
                 'Xylophone',
                 'Tubular Bells',
                 'Dulcimer',
                 'Drawbar Organ',
                 'Percussive Organ',
                 'Rock Organ',
                 'Church Organ',
                 'Reed Organ',
                 'Accordion',
                 'Harmonica',
                 'Tango Accordion',
                 'Acoustic Guitar (Nylon)',
                 'Acoustic Guitar (Steel)',
                 'Electric Guitar (Jazz)',
                 'Electric Guitar (Clean)',
                 'Electric Guitar (Muted)',
                 'Overdriven Guitar',
                 'Distortion Guitar',
                 'Guitar Harmonics',
                 'Acoustic Bass',
                 'Electric Bass (Finger)',
                 'Electric Bass (Pick)',
                 'Fretless Bass',
                 'Slap Bass 1',
                 'Slap Bass 2',
                 'Synth Bass 1',
                 'Synth Bass 2',
                 'Violin',
                 'Viola',
                 'Cello',
                 'Contrabass',
                 'Tremolo Strings',
                 'Pizzicato Strings',
                 'Orchestral Harp',
                 'Timpani',
                 'String Ensemble 1',
                 'String Ensemble 2',
                 'Synth Strings 1',
                 'Synth Strings 2',
                 'Choir Aahs',
                 'Voice Oohs',
                 'Synth Choir',
                 'Orchestra Hit',
                 'Trumpet',
                 'Trombone',
                 'Tuba',
                 'Muted Trumpet',
                 'French Horn',
                 'Brass Section',
                 'Synth Brass 1',
                 'Synth Brass 2',
                 'Soprano Sax',
                 'Alto Sax',
                 'Tenor Sax',
                 'Baritone Sax',
                 'Oboe',
                 'English Horn',
                 'Bassoon',
                 'Clarinet',
                 'Piccolo',
                 'Flute',
                 'Recorder',
                 'Pan Flute',
                 'Blown Bottle',
                 'Shakuhachi',
                 'Whistle',
                 'Ocarina',
                 'Lead 1 (Square)',
                 'Lead 2 (Sawtooth)',
                 'Lead 3 (Calliope)',
                 'Lead 4 (Chiff)',
                 'Lead 5 (Charang)',
                 'Lead 6 (Voice)',
                 'Lead 7 (Fifths)',
                 'Lead 8 (Bass + Lead)',
                 'Pad 1 (New Age)',
                 'Pad 2 (Warm)',
                 'Pad 3 (Polysynth)',
                 'Pad 4 (Choir)',
                 'Pad 5 (Bowed)',
                 'Pad 6 (Metallic)',
                 'Pad 7 (Halo)',
                 'Pad 8 (Sweep)',
                 'Rain FX 1',
                 'Soundtrack FX 2',
                 'Crystal FX 3',
                 'Atmosphere FX 4',
                 'Brightness FX 5',
                 'Goblins FX 6',
                 'Echoes FX 7',
                 'Sci-Fi FX 8',
                 'Sitar',
                 'Banjo',
                 'Shamisen',
                 'Koto',
                 'Kalimba',
                 'Bagpipe',
                 'Fiddle',
                 'Shanai',
                 'Tinkle Bell',
                 'Agogo',
                 'Steel Drums',
                 'Woodblock',
                 'Taiko Drum',
                 'Melodic Tom',
                 'Synth Drum',
                 'Reverse Cymbal',
                 'Guitar Fret Noise',
                 'Breath Noise',
                 'Seashore',
                 'Bird Tweet',
                 'Telephone Ring',
                 'Helicopter',
                 'Applause',
                 'Gunshot');
  my $fillSpaces;
  
  for (1 .. 128) {
    if ($_ < 10) {
      $fillSpaces = '   - ';
    } elsif ($_ < 100) {
      $fillSpaces = '  - ';
    } else {
      $fillSpaces = ' - ';
    }
    $_[0]->append_text($_ . $fillSpaces . $patches[$_ - 1]);
  }
  
  $_[0]->set_active(0);
}

# builds UI
sub app_build {
  my ($app) = @_;
  
  # create Builder from UI file
  my $builder = Gtk3::Builder->new_from_file('../SeekMIDI.ui');
  
  # get window and connect it to our app
  my $window = $builder->get_object('window');
  $window->set_application($app);
  
  # get the other widgets we need
  my $grid = $builder->get_object('grid');
  my $patchCombo = $builder->get_object('patchCombo');
  
  # add the patch choices to the combo box
  patchPopulate($patchCombo);
  
  # creates main widget
  my $mainWidget = Gtk3::MIDIPlot->new();
  $grid->attach($mainWidget, 0, 2, 4, 1);
  
  # make the main widget fill available space
  $mainWidget->set_hexpand(1);
  $mainWidget->set_vexpand(1);

  my $saveAsAction = Glib::IO::SimpleAction->new('saveas', undef);
  $saveAsAction->signal_connect('activate' => \&midiWrite, [$mainWidget, $patchCombo, 24, $window]);
  $window->add_action($saveAsAction);
  
  my $quitAction = Glib::IO::SimpleAction->new('quit', undef);
  $quitAction->signal_connect('activate' => sub{$app->quit()});
  $app->add_action($quitAction);

  # allow for window delete
  $window->signal_connect('delete_event' => sub{$app->quit()});

  $window->show_all();
  $mainWidget->get_VBox()->hide();
}

my $app = Gtk3::Application->new('com.oldtechaa.seekmidi', 'flags-none');

$app->signal_connect('activate' => \&app_build);
$app->run();

0;
