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

# custom widget class; separate from main package below
package Gtk3::MIDIPlot;

use warnings;
use strict;

# invoke dependency modules
use Gtk3;
use Pango;
use Readonly;
use POSIX;
use base 'Gtk3::Box';

our $VERSION = 0.03;

Readonly my $FALSE => 0;
Readonly my $TRUE  => 1;

Readonly my $NOTE_ENABLED   => 0;
Readonly my $NOTE_CONTINUED => 1;
Readonly my $NOTE_START     => 2;
Readonly my $NOTE_LENGTH    => 3;
Readonly my $NOTE_VOLUME    => 4;

# set up black-white key pattern on left sidebar
Readonly::Array my @KEYS => (0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0,
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
my ($xindent, $yindent) = (3 * $cell_width, 2 * $cell_height);

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
sub refresh {
    # gets Cairo context
    my ($this, $cairo) = @_;

	# set up increment variable and current clip extents
	my $inc;
    my ($xmin, $ymin, $xmax, $ymax) = (($cairo->clip_extents())[0], ($cairo->clip_extents())[1], ($cairo->clip_extents())[2], ($cairo->clip_extents())[3]);
	Readonly my $CELLS_PER_WHOLE => 96 / $cell_time;

    # sets drawing color for main grid
    $cairo->set_source_rgb(0.75, 0.75, 0.75);

    # these two loops create the background grid
    for ($inc = POSIX::ceil(($xmin + $xindent) / $cell_width) * $cell_width; $inc <= $xmax; $inc += $cell_width) {
        $cairo->move_to($inc, $ymin + $yindent);
        $cairo->line_to($inc, $ymax);
    }
    for ($inc = POSIX::ceil(($ymin + $yindent) / $cell_height) * $cell_height; $inc <= $ymax; $inc += $cell_height) {
        $cairo->move_to($xmin + $xindent, $inc);
        $cairo->line_to($xmax, $inc);
    }
    $cairo->stroke();

    $cairo->set_source_rgb(0.5, 0.5, 0.5);

    # set up Pango for time header tray
    my $pango = Pango::Cairo::create_layout($cairo);
    my $pango_attributes = Pango::AttrList->new();
    $pango_attributes->insert(Pango::AttrSize->new(8192));
    $pango->set_attributes($pango_attributes);
    
    # draw time header tray
    # the for init takes xmin (pixel), converts to cell, rounds up to whole note, re-multiplies to pixel of xmin visible whole note boundary
    # the for iterator adds the number of pixels in a whole note
    for ($inc = POSIX::ceil($xmin / $cell_width / $CELLS_PER_WHOLE) * $CELLS_PER_WHOLE * $cell_width + $xindent; $inc <= $xmax; $inc += $CELLS_PER_WHOLE * $cell_width) {
        $pango->set_text(($inc - $xindent) / $cell_width / $CELLS_PER_WHOLE);
        my ($pango_width, $pango_height) = $pango->get_size();
        $cairo->move_to($inc - $pango_width / Pango->scale() / 2, $ymin + $yindent - ($cell_height * 1.5));
        Pango::Cairo::show_layout($cairo, $pango);
        
        $cairo->move_to($inc, $ymin + $yindent);
        $cairo->line_to($inc, $ymax);
    }
    
    # draw darker ymin and ymax lines
    if ($ymin == 0) {
        $cairo->move_to($xmin + $xindent, $yindent);
        $cairo->line_to($xmax, $yindent);
    }
    if ($ymax == 130 * $cell_height) {
        $cairo->move_to($xmin + $xindent, $ymax);
        $cairo->line_to($xmax, $ymax);
    }
    
    $cairo->stroke();

    # create the piano key sidebar
    $cairo->set_source_rgb(0, 0, 0);
    for ($inc = POSIX::floor(($ymin + $yindent) / $cell_height) * $cell_height; $inc <= $ymax; $inc += $cell_height) {
        if ($KEYS[127 - ($inc / $cell_height - 2)] == $TRUE) {
            $cairo->rectangle($xmin, $inc + 1, ($cell_width * 3) * 0.8, $cell_height * 0.75);
        }
    }

    # this checks for events with their state set to true, then draws them, scanning the leftmost column first, then all others
    for ($inc = POSIX::floor($ymin / $cell_height); $inc <= ($ymax - $yindent) / $cell_height; $inc++) {
        if (is_enabled(POSIX::floor($xmin / $cell_width), $inc)) {
            my $start_note = $notes[POSIX::floor($xmin / $cell_width)][$inc][$NOTE_START];
            $cairo->rectangle(POSIX::floor($xmin / $cell_width) * $cell_width + $xindent, $inc * $cell_height + $yindent, $notes[$start_note][$inc][$NOTE_LENGTH] * $cell_width, $cell_height);
        }
    }
    for (my $incx = POSIX::floor($xmin / $cell_width + 1) * $cell_width; $incx <= ($xmax - $xindent) / $cell_width; $incx++) {
        for (my $incy = POSIX::floor($ymin / $cell_height) * $cell_height; $incy <= ($ymax - $yindent) / $cell_height; $incy++) {
            if (is_enabled($incx, $incy) && $notes[$incx][$incy][$NOTE_CONTINUED] == $FALSE) {
                $cairo->rectangle($incx * $cell_width + $xindent, $incy * $cell_height + $yindent, $notes[$incx][$incy][$NOTE_LENGTH] * $cell_width, $cell_height);
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

1;
