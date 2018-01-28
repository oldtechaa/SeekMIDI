#!/usr/bin/perl

# SeekMIDI, a simple graphical MIDI sequencer
# This software is copyright (c) 2017 by oldtechaa <oldtechaa@gmail.com>.

# This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming language system itself.

# ALWAYS MAINTAIN NO WARNINGS AND NO ERRORS!
use warnings;
use strict;

package App::SeekMIDI::Widget v0.03;

# invoke dependency modules
use Gtk3;
use base 'Gtk3::Box';
use Pango;

my ( $TRUE, $FALSE ) = ( 1, 0 );
my ( $ENABLED, $CONTINUED, $START, $LENGTH, $VOLUME ) = ( 0, 1, 2, 3, 4 );

# makes a package-global array that holds note objects, and the global drawing area
my @Notes;

# set up package-global variables for widgets that need to be accessed throughout the package
my $This;
my $Scroll;
my $Vol_Scale;
my $Vol_Reveal;

# drag flag
my $Drag_Row;

# set up black-white key pattern on left sidebar
my @KEYS = (
    $FALSE, $TRUE,  $FALSE, $TRUE,  $FALSE, $FALSE, $TRUE,  $FALSE, $TRUE,
    $FALSE, $TRUE,  $FALSE, $FALSE, $TRUE,  $FALSE, $TRUE,  $FALSE, $FALSE,
    $TRUE,  $FALSE, $TRUE,  $FALSE, $TRUE,  $FALSE, $FALSE, $TRUE,  $FALSE,
    $TRUE,  $FALSE, $FALSE, $TRUE,  $FALSE, $TRUE,  $FALSE, $TRUE,  $FALSE,
    $FALSE, $TRUE,  $FALSE, $TRUE,  $FALSE, $FALSE, $TRUE,  $FALSE, $TRUE,
    $FALSE, $TRUE,  $FALSE, $FALSE, $TRUE,  $FALSE, $TRUE,  $FALSE, $FALSE,
    $TRUE,  $FALSE, $TRUE,  $FALSE, $TRUE,  $FALSE, $FALSE, $TRUE,  $FALSE,
    $TRUE,  $FALSE, $FALSE, $TRUE,  $FALSE, $TRUE,  $FALSE, $TRUE,  $FALSE,
    $FALSE, $TRUE,  $FALSE, $TRUE,  $FALSE, $FALSE, $TRUE,  $FALSE, $TRUE,
    $FALSE, $TRUE,  $FALSE, $FALSE, $TRUE,  $FALSE, $TRUE,  $FALSE, $FALSE,
    $TRUE,  $FALSE, $TRUE,  $FALSE, $TRUE,  $FALSE, $FALSE, $TRUE,  $FALSE,
    $TRUE,  $FALSE, $FALSE, $TRUE,  $FALSE, $TRUE,  $FALSE, $TRUE,  $FALSE,
    $FALSE, $TRUE,  $FALSE, $TRUE,  $FALSE, $FALSE, $TRUE,  $FALSE, $TRUE,
    $FALSE, $TRUE,  $FALSE, $FALSE, $TRUE,  $FALSE, $TRUE,  $FALSE, $FALSE,
    $TRUE,  $FALSE
);

# set up single note selection
my @Selection_Single = ( -1, -1 );

# set some global defaults
my ( $Cell_Width, $Cell_Height, $Num_Cells, $Cell_Time, $Vol_Preset ) =
  ( 12, 8, 2400, 6, 127 );

# sets up the class; asks for the signals we need; sets main widget size
sub new {
    $This = Gtk3::DrawingArea->new();
    my $box_h = bless Gtk3::Box->new( 'horizontal', 0 ), shift;
    $Scroll = Gtk3::ScrolledWindow->new();
    my $box_v = Gtk3::Box->new( 'vertical', 0 );
    my $vol_label = Gtk3::Label->new(' Volume: ');
    $Vol_Scale = Gtk3::Scale->new_with_range( 'vertical', 0, 127, 1 );
    $Vol_Reveal = Gtk3::Revealer->new();

    $Vol_Scale->set_inverted($TRUE);

    $box_h->pack_start( $Scroll,     $TRUE,  $TRUE,  0 );
    $box_h->pack_start( $Vol_Reveal, $FALSE, $FALSE, 0 );

    $Scroll->add_with_viewport($This);

    $box_v->pack_start( $vol_label, $FALSE, $FALSE, 0 );
    $box_v->pack_start( $Vol_Scale, $TRUE,  $TRUE,  0 );
    $Vol_Reveal->add($box_v);
    $Vol_Reveal->set_transition_type('slide_right');

    $This->signal_connect( 'draw' => 'App::SeekMIDI::Widget::refresh' );
    $This->signal_connect( 'button_press_event' => 'App::SeekMIDI::Widget::button' );
    $This->signal_connect(
        'motion_notify_event' => 'App::SeekMIDI::Widget::motion' );
    $This->signal_connect(
        'button_release_event' => 'App::SeekMIDI::Widget::release' );
    $This->signal_connect(
        'realize' => sub {
            $This->get_window()->set_events(
                [
                    'button-press-mask', 'button-motion-mask',
                    'button-release-mask'
                ]
            );
        }
    );

    $Scroll->get_hadjustment->signal_connect(
        'value_changed' => sub { $This->queue_draw() } );
    $Scroll->get_vadjustment->signal_connect(
        'value_changed' => sub { $This->queue_draw() } );

    $Vol_Scale->get_adjustment->signal_connect(
        'value_changed' => 'App::SeekMIDI::Widget::vol_changed' );

    $This->set_size_request( ( $Num_Cells + 3 ) * $Cell_Width,
        130 * $Cell_Height );

    return $box_h;
}

# refresh handler; handles drawing grid and objects
# NOTE: $xmin, $ymin refer to grid area coordinates, NOT global drawing area coordinates. 3 cells on the left and 2 on top are taken by sidebar and header
sub refresh {

    # gets Cairo context
    my ( $widget, $cairo ) = @_;

    # sets drawing color for main grid
    $cairo->set_source_rgb( 0.75, 0.75, 0.75 );

    # get the current scroll positions and size of the window, then convert to grid-blocks, adjusting to draw surrounding blocks also, and make sure we don't go out of bounds
    my ( $xmin, $ymin, $xmax, $ymax ) = (
        int( ( $cairo->clip_extents() )[0] / $Cell_Width ) + 3,
        int( ( $cairo->clip_extents() )[1] / $Cell_Height ) + 2,
        int( ( $cairo->clip_extents() )[2] / $Cell_Width ),
        int( ( $cairo->clip_extents() )[3] / $Cell_Height )
    );

    # these two loops create the background grid
    for ( $xmin .. $xmax ) {
        $cairo->move_to( $_ * $Cell_Width, $ymin * $Cell_Height );
        $cairo->line_to( $_ * $Cell_Width, $ymax * $Cell_Height );
    }
    for ( $ymin .. $ymax ) {
        $cairo->move_to( $xmin * $Cell_Width, $_ * $Cell_Height );
        $cairo->line_to( $xmax * $Cell_Width, $_ * $Cell_Height );
    }

    # the grid must be drawn before we start redrawing the key objects
    $cairo->stroke();

    $cairo->set_source_rgb( 0.5, 0.5, 0.5 );

    # set up Pango for time header
    my $pango            = Pango::Cairo::create_layout($cairo);
    my $pango_attributes = Pango::AttrList->new();
    $pango_attributes->insert( Pango::AttrSize->new(8192) );
    $pango->set_attributes($pango_attributes);

    # draw time header and darker lines on time divisions
    for ( $xmin - 3 .. $xmax - 3 ) {
        if ( $_ % ( 96 / $Cell_Time ) == 0 ) {
            $cairo->move_to( ( $_ + 3 ) * $Cell_Width, $ymin * $Cell_Height );
            $cairo->line_to( ( $_ + 3 ) * $Cell_Width, $ymax * $Cell_Height );

            $pango->set_text( $_ / ( 96 / $Cell_Time ) );
            my ( $pango_width, $pango_height ) = $pango->get_size();
            $cairo->move_to(
                $_ * $Cell_Width -
                  $pango_width / Pango->scale() / 2 +
                  3 * $Cell_Width,
                $ymin * $Cell_Height - ( $Cell_Height * 1.5 )
            );
            Pango::Cairo::show_layout( $cairo, $pango );
        }
    }

    # draw darker top and bottom lines
    if ( $ymin == 2 ) {
        $cairo->move_to( $xmin * $Cell_Width, 2 * $Cell_Height );
        $cairo->line_to( $xmax * $Cell_Width, 2 * $Cell_Height );
    }
    if ( $ymax == 130 ) {
        $cairo->move_to( $xmin * $Cell_Width, 130 * $Cell_Height );
        $cairo->line_to( $xmax * $Cell_Width, 130 * $Cell_Height );
    }

    # stroke the darker lines
    $cairo->stroke();

    # create the piano key sidebar
    $cairo->set_source_rgb( 0, 0, 0 );
    for ( $ymin .. $ymax - 1 ) {
        if ( $KEYS[ 127 - ( $_ - 2 ) ] == $TRUE ) {
            $cairo->rectangle(
                ( $xmin - 3 ) * $Cell_Width,
                $_ * $Cell_Height + 1,
                ( $Cell_Width * 3 ) * 0.8,
                $Cell_Height * 0.75
            );
        }
    }

# this checks for events with their state set to true, then draws them, scanning the leftmost column first, then all others
    for ( $ymin .. $ymax - 1 ) {
        if ( is_enabled( $xmin - 3, $_ - 2 ) ) {
            my $start = $Notes[ $xmin - 3 ][ $_ - 2 ][$START];
            $cairo->rectangle(
                $xmin * $Cell_Width,
                $_ * $Cell_Height,
                (
                    $Notes[$start][ $_ - 2 ][$LENGTH] -
                      ( ( $xmin - 3 ) - $start )
                  ) * $Cell_Width,
                $Cell_Height
            );
        }
    }
    for my $incx ( $xmin + 1 .. $xmax - 1 ) {
        for my $incy ( $ymin .. $ymax - 1 ) {
            if ( is_enabled( $incx - 3, $incy - 2 )
                && $Notes[ $incx - 3 ][ $incy - 2 ][$CONTINUED] == $FALSE )
            {
                $cairo->rectangle(
                    $incx * $Cell_Width,
                    $incy * $Cell_Height,
                    $Notes[ $incx - 3 ][ $incy - 2 ][$LENGTH] * $Cell_Width,
                    $Cell_Height
                );
            }
        }
    }

# fill applies the black source onto the destination through the mask with rectangular holes
    $cairo->fill();
}

# handles mouse-clicks on the custom widget
sub button {
    my ( $widget, $event ) = @_;

    my ( $xcell, $ycell ) = (
        ( $event->x - ( $event->x % $Cell_Width ) ) / $Cell_Width,
        ( $event->y - ( $event->y % $Cell_Height ) ) / $Cell_Height
    );
    my ( $xmin, $ymin ) = (
        int( $Scroll->get_hadjustment()->get_value() / $Cell_Width ) + 3,
        int( $Scroll->get_vadjustment()->get_value() / $Cell_Height ) + 2
    );
    my ( $x, $y ) = ( $xcell - 3, $ycell - 2 );

    # left mouse button
    if ( $event->button == 1 ) {
        if ( $xcell >= $xmin && $ycell >= $ymin ) {
            if ( is_enabled( $x, $y ) ) {

                # select a note
                select_note( $Notes[$x][$y][$START], $y );
            }
            else {
                # add a note and refresh
                add_note( $x, $y );
                $This->queue_draw();

                $Drag_Row = $y;
            }
        }

        # right mouse button
    }
    elsif ( $event->button == 3 ) {
        if ( $xcell >= $xmin && $ycell >= $ymin ) {
            if ( is_enabled( $x, $y ) ) {

                # remove the note
                @Selection_Single = ( -1, -1 )
                  if @Selection_Single = ( $Notes[$x][$y][$START], $y );

                for ( $Notes[$x][$y][$START] .. $Notes[$x][$y][$START] +
                    $Notes[ $Notes[$x][$y][$START] ][$y][$LENGTH] -
                    1 )
                {
                    $Notes[$_][$y][$ENABLED] = $FALSE;
                }
            }
            else {
                # turn off selection
                @Selection_Single = ( -1, -1 );
            }

            # hide volume slider
            $Vol_Reveal->set_reveal_child($FALSE);
            $Vol_Reveal->hide();
            $This->queue_draw();
        }
    }
}

# handles mouse drag across the widget
sub motion {
    my ( $widget, $event ) = @_;

    my ( $xcell, $ycell ) = (
        ( $event->x - ( $event->x % $Cell_Width ) ) / $Cell_Width,
        ( $event->y - ( $event->y % $Cell_Height ) ) / $Cell_Height
    );
    my ( $xmin, $ymin ) = (
        int( $Scroll->get_hadjustment()->get_value() / $Cell_Width ) + 3,
        int( $Scroll->get_vadjustment()->get_value() / $Cell_Height ) + 2
    );
    my ( $x, $y ) = ( $xcell - 3, $ycell - 2 );

# check if the underlying cell is set or not and if not, check which mouse button is pressed, then set $Notes and refresh
    if ( defined($Drag_Row) ) {
        if ( $xcell >= $xmin ) {
            add_note( $x, $Drag_Row );
            $This->queue_draw();
        }
    }
}

# clears the current drag row when the drag is ended
sub release {
    undef $Drag_Row;
}

# creates a new note and selects it
sub add_note {
    my ( $x, $y ) = @_;

    @{ $Notes[$x][$y] }[ $ENABLED, $CONTINUED, $START ] = ( $TRUE, $FALSE, $x );
    if ( is_enabled( $x - 1, $y ) ) {
        @{ $Notes[$x][$y] }[ $CONTINUED, $START ] =
          ( $TRUE, $Notes[ $x - 1 ][$y][$START] );
    }
    for ( $Notes[$x][$y][$START] + 1 .. $Num_Cells ) {
        if ( is_enabled( $_, $y ) ) {
            @{ $Notes[$_][$y] }[ $CONTINUED, $START ] =
              ( $TRUE, $Notes[$x][$y][$START] );
        }
        else {
            $Notes[ $Notes[$x][$y][$START] ][$y][$LENGTH] =
              $_ - $Notes[$x][$y][$START];
            last;
        }
    }

    select_note( $Notes[$x][$y][$START], $y );
}

# sets a note's selected attribute to true
sub select_note {
    my ( $x, $y ) = @_;
    @Selection_Single = ( $x, $y );

    # show volume slider for selected note
    $Vol_Reveal->show();
    $Vol_Reveal->set_reveal_child(1);
    if ( !$Notes[ $Notes[$x][$y][$START] ][$y][$VOLUME] ) {
        $Notes[ $Notes[$x][$y][$START] ][$y][$VOLUME] = $Vol_Preset;
    }
    $Vol_Scale->get_adjustment()
      ->set_value( $Notes[ $Notes[$x][$y][$START] ][$y][$VOLUME] );
}

# changes volume attribute of a note
sub vol_changed {
    my $scale = shift;

    $Notes[ $Selection_Single[0] ][ $Selection_Single[1] ][$VOLUME] =
      $scale->get_value();
}

# gets the actual MIDI data for output
sub get_midi {
    my @events;

    push( @events, [ 'patch_change', 0, 0, pop ] );

    for ( 0 .. 127 ) {
        if ( is_enabled( 0, $_ ) ) {
            push( @events,
                [ 'note_on', 0, 0, 127 - $_, $Notes[0][$_][$VOLUME] ] );
        }
    }
    my $delta = $Cell_Time;
    for my $incx ( 1 .. $Num_Cells ) {
        for my $incy ( 0 .. 127 ) {
            if ( !is_enabled( $incx, $incy ) && is_enabled( $incx - 1, $incy ) )
            {
                push(
                    @events,
                    [
                        'note_off',
                        $delta,
                        0,
                        127 - $incy,
                        $Notes[ $Notes[ $incx - 1 ][$incy][$START] ][$incy]
                          [$VOLUME]
                    ]
                );
                $delta = 0;
            }
            elsif ( is_enabled( $incx, $incy )
                && !is_enabled( $incx - 1, $incy ) )
            {
                push(
                    @events,
                    [
                        'note_on', $delta, 0,
                        127 - $incy,
                        $Notes[$incx][$incy][$VOLUME]
                    ]
                );
                $delta = 0;
            }
        }
        $delta += $Cell_Time;
    }

    return \@events;
}

# makes it so we can get the volume revealer from outside the package
sub get_vol_reveal {
    return $Vol_Reveal;
}

# tells us whether a cell contains (part of) a note
sub is_enabled {
    my ( $x, $y ) = @_;
    if ( $Notes[$x][$y][$ENABLED] ) {
        return $TRUE;
    }
    else {
        return $FALSE;
    }
}
