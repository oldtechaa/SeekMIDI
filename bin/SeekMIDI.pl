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

my $FALSE = 0;
my $TRUE  = 1;

# custom widget class; separate from main package below
package Gtk3::MIDIPlot;

# invoke dependency modules
use Gtk3;
use base 'Gtk3::Box';
use Pango;

my $NOTE_ENABLED   = 0;
my $NOTE_CONTINUED = 1;
my $NOTE_START     = 2;
my $NOTE_LENGTH    = 3;
my $NOTE_VOLUME    = 4;

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
            0, 1, 0, 1, 0, 0, 1, 0,);

# makes a package-global array that holds note objects, and the global drawing area
my @notes;

# set up package-global variables for widgets that need to be accessed throughout the package
my $scroll;
my $volume_slider;
my $volume_reveal;

# initialize the drag variables to a no-drag state
my ($drag_row, $drag_start, $drag_mode) = (-1, -1, -1);

# set up single note selection
my @select_single = (-1, -1);

# set some global constants
my ($cell_width, $cell_height, $number_of_cells, $cell_time, $default_volume) = (12, 8, 2400, 6, 127);

# sets up the class; asks for the signals we need; sets main widget size
sub new {
    my $canvas = Gtk3::DrawingArea->new();
    my $this = bless Gtk3::Box->new('horizontal', 6), shift;
    $scroll = Gtk3::ScrolledWindow->new();
    my $vbox = Gtk3::Box->new('vertical', 6);
    my $volume_label = Gtk3::Label->new('Vol: ');
    $volume_slider = Gtk3::Scale->new_with_range('vertical', 0, 127, 1);
    $volume_reveal = Gtk3::Revealer->new();

    $volume_slider->set_inverted(1);

    $this->pack_start($scroll, $TRUE, $TRUE, 0);
    $this->pack_start($volume_reveal, $FALSE, $FALSE, 0);

    $scroll->add_with_viewport($canvas);

    $vbox->pack_start($volume_label, $FALSE, $FALSE, 0);
    $vbox->pack_start($volume_slider, $TRUE, $TRUE, 0);
    $volume_reveal->add($vbox);
    $volume_reveal->set_transition_type('slide_right');

    $canvas->signal_connect('draw' => 'Gtk3::MIDIPlot::refresh');
    $canvas->signal_connect('button_press_event' => 'Gtk3::MIDIPlot::button');
    $canvas->signal_connect('motion_notify_event' => 'Gtk3::MIDIPlot::motion');
    $canvas->signal_connect('button_release_event' => 'Gtk3::MIDIPlot::release');
    $canvas->signal_connect('realize' => sub{$canvas->get_window()->set_events(['button-press-mask', 'button-motion-mask', 'button-release-mask'])});

    $scroll->get_hadjustment->signal_connect('value_changed' => sub {$canvas->queue_draw()});
    $scroll->get_vadjustment->signal_connect('value_changed' => sub {$canvas->queue_draw()});

    $volume_slider->get_adjustment->signal_connect('value_changed' => 'Gtk3::MIDIPlot::volume_changed');

    $canvas->set_size_request(($number_of_cells + 3) * $cell_width, 130 * $cell_height);

    return $this;
}

# refresh handler; handles drawing grid and objects
# NOTE: $xmin, $ymin refer to grid area coordinates, NOT global drawing area coordinates. 3 cells on the left and 2 on top are taken by sidebar and header
sub refresh {
    # gets Cairo context
    my ($this, $cairo) = @_;

    # sets drawing color for main grid
    $cairo->set_source_rgb(0.75, 0.75, 0.75);

    # get the current scroll positions and size of the window, then convert to grid-blocks, adjusting to draw surrounding blocks also, and make sure we don't go out of bounds
    my ($xmin, $ymin, $xmax, $ymax) = (int(($cairo->clip_extents())[0] / $cell_width) + 3, int(($cairo->clip_extents())[1] / $cell_height) + 2, int(($cairo->clip_extents())[2] / $cell_width), int(($cairo->clip_extents())[3] / $cell_height));

    # these two loops create the background grid
    for ($xmin .. $xmax) {
        $cairo->move_to($_ * $cell_width, $ymin * $cell_height);
        $cairo->line_to($_ * $cell_width, $ymax * $cell_height);
    }
    for ($ymin .. $ymax) {
        $cairo->move_to($xmin * $cell_width, $_ * $cell_height);
        $cairo->line_to($xmax * $cell_width, $_ * $cell_height);
    }

    # the grid must be drawn before we start redrawing the key objects
    $cairo->stroke();

    $cairo->set_source_rgb(0.5, 0.5, 0.5);

    # set up Pango for time header
    my $pango = Pango::Cairo::create_layout($cairo);
    my $pango_attributes = Pango::AttrList->new();
    $pango_attributes->insert(Pango::AttrSize->new(8192));
    $pango->set_attributes($pango_attributes);

    # draw time header and darker lines on time divisions
    for ($xmin - 3 .. $xmax - 3) {
        if ($_ % (96 / $cell_time) == 0) {
            $cairo->move_to(($_ + 3) * $cell_width, $ymin * $cell_height);
            $cairo->line_to(($_ + 3) * $cell_width, $ymax * $cell_height);

            $pango->set_text($_ / (96 / $cell_time));
            my ($pango_width, $pango_height) = $pango->get_size();
            $cairo->move_to($_ * $cell_width - $pango_width / Pango->scale() / 2 + 3 * $cell_width, $ymin * $cell_height - ($cell_height * 1.5));
            Pango::Cairo::show_layout($cairo, $pango);
        }
    }

    # draw darker top and bottom lines
    if ($ymin == 2) {
        $cairo->move_to($xmin * $cell_width, 2 * $cell_height);
        $cairo->line_to($xmax * $cell_width, 2 * $cell_height);
    }
    if ($ymax == 130) {
        $cairo->move_to($xmin * $cell_width, 130 * $cell_height);
        $cairo->line_to($xmax * $cell_width, 130 * $cell_height);
    }

    # stroke the darker lines
    $cairo->stroke();

    # create the piano key sidebar
    $cairo->set_source_rgb(0, 0, 0);
    for ($ymin .. $ymax - 1) {
        if ($keys[127 - ($_ - 2)] == $TRUE) {
            $cairo->rectangle(($xmin - 3) * $cell_width, $_ * $cell_height + 1, ($cell_width * 3) * 0.8, $cell_height * 0.75);
        }
    }

    # this checks for events with their state set to true, then draws them, scanning the leftmost column first, then all others
    for ($ymin .. $ymax - 1) {
        if (is_enabled($xmin - 3, $_ - 2)) {
            my $start_note = $notes[$xmin - 3][$_ - 2][$NOTE_START];
            $cairo->rectangle($xmin * $cell_width, $_ * $cell_height, ($notes[$start_note][$_ - 2][$NOTE_LENGTH] - (($xmin - 3) - $start_note)) * $cell_width, $cell_height);
        }
    }
    for my $incx ($xmin + 1 .. $xmax - 1) {
        for my $incy ($ymin .. $ymax - 1) {
            if (is_enabled($incx - 3, $incy - 2) && $notes[$incx - 3][$incy - 2][$NOTE_CONTINUED] == $FALSE) {
                $cairo->rectangle($incx * $cell_width, $incy * $cell_height, $notes[$incx - 3][$incy - 2][$NOTE_LENGTH] * $cell_width, $cell_height);
            }
        }
    }

    # fill applies the black source onto the destination through the mask with rectangular holes
    $cairo->fill();

    return;
}

# handles mouse-clicks on the custom widget
sub button {
    my ($this, $event) = @_;

    my ($xcell, $ycell) = (($event->x - ($event->x % $cell_width)) / $cell_width, ($event->y - ($event->y % $cell_height)) / $cell_height);
    my ($xmin, $ymin) = (int($scroll->get_hadjustment()->get_value() / $cell_width) + 3, int($scroll->get_vadjustment()->get_value() / $cell_height) + 2);
    my ($x, $y) = ($xcell - 3, $ycell - 2);

    my $max_cell = $number_of_cells - 1;

    # left mouse button
    if ($event->button == 1) {
        if ($xcell >= $xmin && $ycell >= $ymin) {
            if (is_enabled($x, $y)) {
                # select a note
                select_note($notes[$x][$y][$NOTE_START], $y);
            } else {
                # add a note and refresh
                add_note($x, $y);
                $this->queue_draw();

                $drag_mode = 0;
                $drag_row = $y;
            }
        }
    # right mouse button
    } elsif ($event->button == 3) {
        if ($xcell >= $xmin && $ycell >= $ymin) {
            if (is_enabled($x, $y)) {
                # remove the note
                if (@select_single = ($notes[$x][$y][$NOTE_START], $y)) {@select_single = (-1, -1)};

                for ($notes[$x][$y][$NOTE_START] .. $notes[$x][$y][$NOTE_START] + $notes[$notes[$x][$y][$NOTE_START]][$y][$NOTE_LENGTH] - 1) {
                    $notes[$_][$y][$NOTE_ENABLED] = $FALSE;
                }
            } else {
                # turn off selection
                @select_single = (-1, -1);
            }
            # hide volume slider
            $volume_reveal->set_reveal_child($FALSE);
            $volume_reveal->hide();
            $this->queue_draw();
        }
    }

    return;
}

# handles mouse drag across the widget
sub motion {
    my ($this, $event) = @_;

    my ($xcell, $ycell) = (($event->x - ($event->x % $cell_width)) / $cell_width, ($event->y - ($event->y % $cell_height)) / $cell_height);
    my ($xmin, $ymin) = (int($scroll->get_hadjustment()->get_value() / $cell_width) + 3, int($scroll->get_vadjustment()->get_value() / $cell_height) + 2);
    my ($x, $y) = ($xcell - 3, $ycell - 2);

    # check if the underlying cell is set or not and if not, check which mouse button is pressed, then set $notes and refresh
    if ($drag_mode == 0) {
        if ($xcell >= $xmin) {
            add_note($x, $drag_row);
            $this->queue_draw();
        }
    }

    return;
}

# clears the current drag row and mode when the drag is ended
sub release {
    ($drag_row, $drag_mode) = (-1, -1);

    return;
}

# creates a new note and selects it
sub add_note {
    my ($x, $y) = @_;

    @{$notes[$x][$y]}[$NOTE_ENABLED, $NOTE_CONTINUED, $NOTE_START] = ($TRUE, $FALSE, $x);
    if (is_enabled($x - 1, $y)) {
        @{$notes[$x][$y]}[$NOTE_CONTINUED, $NOTE_START] = ($TRUE, $notes[$x - 1][$y][$NOTE_START]);
    }
    for ($notes[$x][$y][$NOTE_START] + 1 .. $number_of_cells) {
        if (is_enabled($_, $y)) {
            @{$notes[$_][$y]}[$NOTE_CONTINUED, $NOTE_START] = ($TRUE, $notes[$x][$y][$NOTE_START]);
        } else {
            $notes[$notes[$x][$y][$NOTE_START]][$y][$NOTE_LENGTH] = $_  - $notes[$x][$y][$NOTE_START];
            last;
        }
    }

    select_note($notes[$x][$y][$NOTE_START], $y);

    return;
}

# sets a note's selected attribute to true
sub select_note {
	my ($x, $y) = @_;
	@select_single = ($x, $y);

    # show volume slider for selected note
    $volume_reveal->show();
    $volume_reveal->set_reveal_child(1);
    if (!$notes[$notes[$x][$y][$NOTE_START]][$y][$NOTE_VOLUME]) {
        $notes[$notes[$x][$y][$NOTE_START]][$y][$NOTE_VOLUME] = $default_volume;
    }
    $volume_slider->get_adjustment()->set_value($notes[$notes[$x][$y][$NOTE_START]][$y][$NOTE_VOLUME]);

    return;
}

# changes volume attribute of a note
sub volume_changed {
    $notes[$select_single[0]][$select_single[1]][$NOTE_VOLUME] = shift->get_value();

    return;
}

# gets the actual MIDI data for output
sub get_data {
    my ($patch) = @_;

    my @events;

    push @events, ['patch_change', 0, 0, $patch];

    for (0 .. 127) {
        if (is_enabled(0, $_)) {
            push @events, ['note_on', 0, 0, 127 - $_, $notes[0][$_][$NOTE_VOLUME]];
        }
    }
    my $delta = $cell_time;
    for my $incx (1 .. $number_of_cells) {
        for my $incy (0 .. 127) {
            if (!is_enabled($incx, $incy) && is_enabled($incx - 1, $incy)) {
                push @events, ['note_off', $delta, 0, 127 - $incy, $notes[$notes[$incx - 1][$incy][$NOTE_START]][$incy][$NOTE_VOLUME]];
                $delta = 0;
            } elsif (is_enabled($incx, $incy) && !is_enabled($incx - 1, $incy)) {
                push @events, ['note_on', $delta, 0, 127 - $incy, $notes[$incx][$incy][$NOTE_VOLUME]];
                $delta = 0;
            }
        }
        $delta += $cell_time;
    }

    return \@events;
}

# makes it so we can get the vbox from outside the package
sub get_volume_reveal {
    return $volume_reveal;
}

# tells us whether a cell contains (part of) a note
sub is_enabled {
    my ($x, $y) = @_;
    if ($notes[$x][$y][$NOTE_ENABLED]) {
        return $TRUE;
    } else {
        return $FALSE;
    }
}

package main;

# append to @INC the corresponding library directory for MIDI.pm
use FindBin;
use File::Spec;
use lib File::Spec->catdir($FindBin::Bin, '../lib');

use MIDI;
use Gtk3;
# use Locale::gettext;

use Glib::Object::Introspection;
Glib::Object::Introspection->setup('basename' => 'Gio', 'version' => '2.0', 'package' => 'Glib::IO');

# writes the MIDI output to a file based on the list of events and the filename that the user enters in a FileChooserDialog
sub midi_write {
    my $dataref = pop;

    my $main_widget = $dataref->[0];
	my $eventref = $main_widget->get_data($dataref->[1]->get_active());
	my $ticks = $dataref->[2];

    my $dialog = Gtk3::FileChooserDialog->new('Save As', $dataref->[3], 'save', '_Cancel', 'cancel', '_Save', 'ok');

    if ($dialog->run() eq 'ok') {
        my $file = $dialog->get_filename();
        $dialog->destroy();

        my $track = MIDI::Track->new({'events' => $eventref});
        my $piece = MIDI::Opus->new({'format' => 0, 'ticks' => $ticks, 'tracks' => [$track]});
        $piece->write_to_file($file);
    } else {
        $dialog->destroy();
    }

    return;
}

# insert entries into the patch list and space properly for vertical alignment
sub patch_populate {
    my $patchbox = shift;

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
                   'Gunshot',);
    my $fill;

    for (1 .. 128) {
        if ($_ < 10) {
            $fill = '   - ';
        } elsif ($_ < 100) {
            $fill = '  - ';
        } else {
            $fill = ' - ';
        }
        $patchbox->append_text($_ . $fill . $patches[$_ - 1]);
    }

    $patchbox->set_active(0);

    return;
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
    my $patchbox = $builder->get_object('patchCombo');

    # add the patch choices to the combo box
    patch_populate($patchbox);

    # creates main widget
    my $main_widget = Gtk3::MIDIPlot->new();
    $grid->attach($main_widget, 0, 2, 4, 1);

    # make the main widget fill available space
    $main_widget->set_hexpand($TRUE);
    $main_widget->set_vexpand($TRUE);

    my $save_as_action = Glib::IO::SimpleAction->new('saveas', undef);
    $save_as_action->signal_connect('activate' => \&midi_write, [$main_widget, $patchbox, 24, $window]);
    $window->add_action($save_as_action);

    my $quit_action = Glib::IO::SimpleAction->new('quit', undef);
    $quit_action->signal_connect('activate' => sub {$app->quit()});
    $app->add_action($quit_action);

    # allow for window delete
    $window->signal_connect('delete_event' => sub {$app->quit()});

    $window->show_all();
    $main_widget->get_volume_reveal()->set_reveal_child($FALSE);
    $main_widget->get_volume_reveal()->hide();

    return;
}

my $app = Gtk3::Application->new('com.oldtechaa.seekmidi', 'flags-none');

$app->signal_connect('activate' => \&app_build);
$app->run();
