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

# append to @INC the corresponding library directory for MIDI.pm
use FindBin;
use File::Spec;
use lib File::Spec->catdir($FindBin::Bin, '../lib');

use MIDI;
use Gtk3;
use Gtk3::MIDIPlot;
use Readonly;
# use Locale::gettext;

use Glib::Object::Introspection;
Glib::Object::Introspection->setup('basename' => 'Gio', 'version' => '2.0', 'package' => 'Glib::IO');

our $VERSION = 0.03;

Readonly my $FALSE => 0;
Readonly my $TRUE  => 1;

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
