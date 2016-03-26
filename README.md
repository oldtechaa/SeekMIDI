### What is this repository for? ###

This is the home of SeekMIDI, a simple graphical MIDI sequencer offering multi-channel MIDI sequencing. Look at [Seq24](https://launchpad.net/seq24/) for a slightly heavier example of what we mean. Written in Perl, SeekMIDI uses GTK+2 and Cairo to provide its GUI and MIDI-Perl to provide its MIDI handling system. We have released one version: 0.1.0. Please download it and try it out.

### How do I get set up? ###

Dependencies listed in the format Upstream/Debian/Arch (may be different on other distributions):

 * MIDI-Perl/libmidi-perl/perl-midi-perl. For convenience on other distributions which do not package the library, the MIDI modules are provided in tarball form. Extract the tarball, then follow the README to install.

 * Gtk2-Perl/libgtk2-perl/gtk2-perl.

 * Cairo-Perl/libcairo-perl/cairo-perl.

 * Locale::gettext/liblocale-gettext-perl/perl-locale-gettext.

 * Perl/perl5/perl.

Once set up, run "perl SeekMIDI.pl" in the folder containing SeekMIDI to run the program.

Please note: An empty filename value may crash the program.

Eventually, we would like to provide packages for MIDI-Perl, and provide a full automated setup procedure for SeekMIDI. Right now, we're working on more important things. We also eventually plan to port it to Windows, but that is low priority. There are no plans to port it to OS X at this moment.

### Contribution guidelines ###

Email me to contribute. I will explain what the goals are, and what our milestones are.

### Who do I talk to? ###

It's just me. [oldtechaa@gmail.com](mailto:oldtechaa@gmail.com)

### The main website ###

The main website's address currently is [the Github repo](https://github.com/oldtechaa/SeekMIDI/).
