#!/usr/bin/perl

# SeekMIDI, a simple graphical MIDI sequencer
# This software is copyright (c) 2017 by oldtechaa <oldtechaa@gmail.com>.

# This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming language system itself.

# ALWAYS MAINTAIN NO WARNINGS AND NO ERRORS!
use warnings;
use strict;

package main v0.03;

# append to @INC the local library directory for MIDI.pm and SeekMIDI::Widget
use FindBin;
use File::Spec;
use lib File::Spec->catdir( $FindBin::Bin, '../lib' );

use MIDI;
use Gtk3;

# use Locale::gettext;

use App::SeekMIDI::Widget;

use Glib::Object::Introspection;
Glib::Object::Introspection->setup(
    'basename' => 'Gio',
    'version'  => '2.0',
    'package'  => 'Glib::IO'
);

my ( $TRUE, $FALSE ) = ( 1, 0 );

my $Ticks = 24;

# extract the midi data based on the main widget and the patch combobox, then pass on to midi_write
sub midi_extract {
    my $data = pop;

    my $widget        = $data->[0];
    my $midi_data_ref = $widget->get_midi( $data->[1]->get_active() );
    my $parent_window = $data->[2];

    midi_write( $midi_data_ref, $parent_window );
}

# writes the MIDI output to a file based on the list of events and the filename that the user enters in a FileChooserDialog
sub midi_write {
    my ( $midi_data_ref, $parent_window ) = @_;

    my $dialog =
      Gtk3::FileChooserDialog->new( 'Save As', $parent_window, 'save',
        '_Cancel', 'cancel', '_Save', 'ok' );

    if ( $dialog->run() eq 'ok' ) {
        my $file = $dialog->get_filename();
        $dialog->destroy();

        my $track = MIDI::Track->new( { 'events' => $midi_data_ref } );
        my $opus = MIDI::Opus->new(
            { 'format' => 0, 'ticks' => $Ticks, 'tracks' => [$track] } );
        $opus->write_to_file($file);
    }
    else {
        $dialog->destroy();
    }
}

# insert entries into the patch list and space properly for vertical alignment
sub patch_init {
    my $combo = shift;

    my @patches = (
        'Grand Piano',
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
        'Gunshot'
    );

    for ( 1 .. 128 ) { $combo->append_text( $_ . ' - ' . $patches[ $_ - 1 ] ) }

    $combo->set_active(0);
}

# builds UI
sub app_build {
    my $app = shift;

    # create Builder from UI file
    my $builder =
      Gtk3::Builder->new_from_file(
        File::Spec->catdir( $FindBin::Bin, '../SeekMIDI.ui' ) );

    # get window and connect it to our app
    my $window = $builder->get_object('window');
    $window->set_application($app);

    # get the other widgets we need
    my $grid        = $builder->get_object('grid');
    my $patch_combo = $builder->get_object('patch_combo');

    # add the patch choices to the combo box
    patch_init($patch_combo);

    # creates main widget
    my $main_widget = App::SeekMIDI::Widget->new();
    $grid->attach( $main_widget, 0, 2, 1, 1 );

    # make the main widget fill available space
    $main_widget->set_hexpand($TRUE);
    $main_widget->set_vexpand($TRUE);

    my $save_as_action = Glib::IO::SimpleAction->new( 'saveas', undef );
    $save_as_action->signal_connect(
        'activate' => \&midi_extract,
        [ $main_widget, $patch_combo, $window ]
    );
    $window->add_action($save_as_action);

    my $quit_action = Glib::IO::SimpleAction->new( 'quit', undef );
    $quit_action->signal_connect( 'activate' => sub { $app->quit() } );
    $app->add_action($quit_action);

    # allow for window delete
    $window->signal_connect( 'delete_event' => sub { $app->quit() } );

    $window->show_all();
    $main_widget->get_vol_reveal()->set_reveal_child($FALSE);
    $main_widget->get_vol_reveal()->hide();
}

my $app = Gtk3::Application->new( 'com.oldtechaa.seekmidi', 'flags-none' );

$app->signal_connect( 'activate' => \&app_build );
$app->run();
